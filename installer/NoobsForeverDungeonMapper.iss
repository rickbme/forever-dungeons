; Windows installer for players: puts NoobsForeverDungeonMapper\ into <WoW>\_forever_\Interface\AddOns.
; Build it (needs Inno Setup 6) from the repo root:
;   iscc installer\NoobsForeverDungeonMapper.iss                       (version read from the toc)
;   iscc /DAppVersion=0.1.0-beta installer\NoobsForeverDungeonMapper.iss  (CI: must match the toc)
; Output: dist\NoobsForeverDungeonMapper-Setup-<version>.exe. See docs/development.md.

#define AddonName "NoobsForeverDungeonMapper"

; The toc's "## Version:" is the one version number; a /DAppVersion that differs is an error,
; so a release can't ship under the wrong number (same rule as tools/package.py).
#define TocVersion ""
#define TocLine ""
#define TocHandle FileOpen(AddBackslash(SourcePath) + "..\" + AddonName + "\" + AddonName + ".toc")
#if !TocHandle
  #error Can't open the addon's .toc
#endif
; The reading happens in the #for's step: a #define inside a #sub only sets a local.
#sub NoOp
#endsub
#for {0; !FileEof(TocHandle) && TocVersion == ""; \
  TocLine = FileRead(TocHandle), \
  TocVersion = Pos("## Version:", TocLine) == 1 ? Trim(Copy(TocLine, Len("## Version:") + 1)) : ""} NoOp
#expr FileClose(TocHandle)
#if TocVersion == ""
  #error No "## Version:" in the .toc
#endif
#ifndef AppVersion
  #define AppVersion TocVersion
#endif
#if AppVersion != TocVersion
  #error AppVersion doesn't match the toc's ## Version:
#endif
; Windows' file version must be numeric: 0.1.0-beta -> 0.1.0
#define NumVersion (Pos("-", AppVersion) > 0 ? Copy(AppVersion, 1, Pos("-", AppVersion) - 1) : AppVersion)

[Setup]
; Never change the AppId: Windows uses it to recognise upgrades and the uninstaller.
AppId={{8705A4B4-2CBC-4DD0-AC47-3602C49B262A}
AppName=Noobs Forever Dungeon Mapper
AppVersion={#AppVersion}
AppPublisher=Noobs Forever
AppPublisherURL=https://github.com/rickbme/noobs-forever-dungeon-mapper
AppSupportURL=https://github.com/rickbme/noobs-forever-dungeon-mapper/issues
VersionInfoVersion={#NumVersion}
; {app} is the World of Warcraft folder (the one holding _forever_), not the addon folder.
DefaultDirName={code:DetectWowDir}
AppendDefaultDirName=no
DirExistsWarning=no
DisableDirPage=no
UsePreviousAppDir=yes
DisableProgramGroupPage=yes
DisableReadyPage=no
; The game is usually under Program Files, which needs admin. /CURRENTUSER on the command line is
; for testing against a folder you can write to.
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=commandline
; Keep the uninstaller out of the game and addon folders.
UninstallFilesDir={autoappdata}\Noobs Forever Dungeon Mapper
UninstallDisplayName=Noobs Forever Dungeon Mapper
; We ask about a running game ourselves; don't offer to close it.
CloseApplications=no
OutputDir=..\dist
OutputBaseFilename={#AddonName}-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Messages]
WizardSelectDir=Find World of Warcraft
SelectDirDesc=Where is World of Warcraft installed?
SelectDirLabel3=Choose the World of Warcraft folder: the one that contains the "_forever_" folder.
SelectDirBrowseLabel=If the folder below is right, click Next. If not, click Browse and pick it.
FinishedHeadingLabel=Noobs Forever Dungeon Mapper is installed
FinishedLabelNoIcons=Start the game, and make sure Noobs Forever Dungeon Mapper is ticked in the AddOns list.
FinishedLabel=Start the game, and make sure Noobs Forever Dungeon Mapper is ticked in the AddOns list.

[InstallDelete]
; Remove the old copy first so no stale files remain; ForeverDungeons is the addon's old name.
; Never touch WTF\: it holds the player's settings and boss progress.
Type: filesandordirs; Name: "{app}\_forever_\Interface\AddOns\{#AddonName}"
Type: filesandordirs; Name: "{app}\_forever_\Interface\AddOns\ForeverDungeons"

[Files]
Source: "..\{#AddonName}\*"; DestDir: "{app}\_forever_\Interface\AddOns\{#AddonName}"; Excludes: ".DS_Store,Thumbs.db,*.pyc,__pycache__"; Flags: recursesubdirs createallsubdirs ignoreversion

[UninstallDelete]
Type: dirifempty; Name: "{app}\_forever_\Interface\AddOns\{#AddonName}"

[Code]
const
  DRIVE_FIXED = 3;
  UninstallKey = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\World of Warcraft';
  BlizzardKey = 'SOFTWARE\Blizzard Entertainment\World of Warcraft';

var
  DetectedDir: String;

function GetDriveType(lpRootPathName: String): UINT;
  external 'GetDriveTypeW@kernel32.dll stdcall';

function IsWowDir(Dir: String): Boolean;
begin
  Result := (Dir <> '') and DirExists(AddBackslash(Dir) + '_forever_');
end;

// Dir or one of its parents (up to 3 levels) that holds _forever_, or '' if none. Accepts the WoW
// folder itself, _forever_ or _retail_, or _forever_\Interface\AddOns.
function WowDirFrom(Dir: String): String;
var
  I: Integer;
begin
  Result := '';
  Dir := RemoveBackslashUnlessRoot(Trim(Dir));
  for I := 0 to 3 do
  begin
    if IsWowDir(Dir) then
    begin
      Result := Dir;
      Exit;
    end;
    if (Dir = '') or (ExtractFileDir(Dir) = Dir) then
      Exit;
    Dir := ExtractFileDir(Dir);
  end;
end;

function FromRegistry(RootKey: Integer; SubKey, Value: String): String;
var
  Path: String;
begin
  Result := '';
  if RegQueryStringValue(RootKey, SubKey, Value, Path) then
    Result := WowDirFrom(Path);
end;

// Blizzard's records can be stale (a game moved to another drive), so every candidate must
// actually contain _forever_.
function FindWowDir(): String;
var
  I, J: Integer;
  Root: String;
  Folders: array of String;
begin
  Result := FromRegistry(HKLM32, UninstallKey, 'InstallLocation');
  if Result = '' then Result := FromRegistry(HKCU, UninstallKey, 'InstallLocation');
  if Result = '' then Result := FromRegistry(HKLM32, BlizzardKey, 'InstallPath');
  if Result = '' then Result := FromRegistry(HKCU, BlizzardKey, 'InstallPath');
  if Result <> '' then
    Exit;

  Folders := ['Program Files (x86)\World of Warcraft', 'Program Files\World of Warcraft',
    'World of Warcraft', 'Games\World of Warcraft'];
  // Fixed drives only: probing an empty card reader or DVD drive can pop up "no disk" errors.
  for I := Ord('C') to Ord('Z') do
  begin
    Root := Chr(I) + ':\';
    if GetDriveType(Root) = DRIVE_FIXED then
      for J := 0 to GetArrayLength(Folders) - 1 do
        if IsWowDir(Root + Folders[J]) then
        begin
          Result := Root + Folders[J];
          Exit;
        end;
  end;
end;

function DetectWowDir(Param: String): String;
begin
  if DetectedDir = '' then
  begin
    DetectedDir := FindWowDir();
    if DetectedDir = '' then
      DetectedDir := ExpandConstant('{commonpf32}\World of Warcraft');
  end;
  Result := DetectedDir;
end;

function AddOnsDir(): String;
begin
  Result := AddBackslash(WizardDirValue) + '_forever_\Interface\AddOns';
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  Dir: String;
begin
  Result := True;
  if CurPageID = wpSelectDir then
  begin
    Dir := WowDirFrom(WizardDirValue);
    if Dir = '' then
    begin
      MsgBox('That folder does not contain "_forever_".' + #13#10#13#10 +
        'Pick the World of Warcraft folder (the one with the _forever_ folder inside), ' +
        'or install WoW Forever with the Battle.net app first.', mbError, MB_OK);
      Result := False;
    end
    else if CompareText(Dir, WizardDirValue) <> 0 then
      // they picked a folder inside the game folder: use the game folder itself
      WizardForm.DirEdit.Text := Dir;
  end;
end;

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo,
  MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
begin
  Result := 'The addon will be put in:' + NewLine + Space + AddOnsDir() + '\{#AddonName}' + NewLine;
  if DirExists(AddOnsDir() + '\{#AddonName}') or DirExists(AddOnsDir() + '\ForeverDungeons') then
    Result := Result + NewLine + 'The copy that is there now will be replaced.' + NewLine;
  Result := Result + NewLine + 'Your settings and boss progress are kept.';
end;

function IsWowRunning(): Boolean;
var
  Locator, Service, Procs: Variant;
begin
  Result := False;
  try
    Locator := CreateOleObject('WbemScripting.SWbemLocator');
    Service := Locator.ConnectServer('.', 'root\CIMV2');
    Procs := Service.ExecQuery('SELECT ProcessId FROM Win32_Process WHERE Name = ''Wow.exe''');
    Result := Procs.Count > 0;
  except
    // no WMI: carry on, the files can be replaced while the game runs anyway
  end;
end;

// The files can be replaced while the game runs, but it only loads them at start-up.
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  while not WizardSilent() and IsWowRunning() do
    if TaskDialogMsgBox('World of Warcraft is running',
      'Please close the game first. It only loads new addons when it starts.',
      mbInformation, MB_YESNO, ['I closed it, check again', 'Install anyway (restart the game afterwards)'],
      0) = IDNO then
      Break;
end;
