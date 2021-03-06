
{$IFDEF OPT_DEBUG}
{$APPTYPE CONSOLE}
{$ENDIF}

program Eschecs;

{$MODE objfpc}{$H+}
{$IFDEF UNIX}
{$DEFINE UseCThreads}
{$ENDIF}

uses
{$IFDEF UNIX}
  cthreads,
  cwstring,
{$ENDIF}
  Classes,
  SysUtils,
  StrUtils,
  RegExpr,
  fpg_base,
  fpg_main,
  fpg_dialogs,
  fpg_menu,
  fpg_widget,
  Images,
  Board,
  Style,
  Utils,
  Language,
  Connect,
  Settings,
  ValidatorCore,
  ChessTypes,
  ChessGame,
  UCI,
  FEN,
  Engines,
  Log,
{$IFDEF OPT_DEBUG}
  TypInfo,
{$ENDIF}
{$IFDEF OPT_SOUND}
  Sound,
{$ENDIF}
{$IFDEF OPT_ECO}
  ECO,
{$ENDIF}
  MoveList,
  messagefrm,
  fpg_style_eschecs,
  fpg_stylemanager,
{%units 'Auto-generated GUI code'}
  fpg_form,
  fpg_panel
{%endunits}
  ;

{$IFDEF windows}
{$R eschecs.res}
{$ENDIF}
{$WARN 5024 OFF}
{$I version.inc}

type
  TNavigation = (nvPrevious, nvNext, nvLast, nvFirst);

  TListener = class(TThread)
  private
    FEngineMessage: string;
    procedure OnEngineMessage;
  protected
    procedure Execute; override;
  end;

  TMainForm = class(TfpgForm)
  protected
    FBGRAChessboard: TBGRAChessboard;
    FBoardStyle: TBoardStyle;
    FUpsideDown: boolean;
    FGame: TChessGame;
    FUserMove, FRookMove: string;
    FUserColor: TChessPieceColor;
    FComputerColor: TChessPieceColorEx;
    FWaiting: boolean;
    FExePath: string;
    FEngine: integer;
    FEngineConnected: boolean;
    FMoveHistory: TMoveList;
    FPositionHistory: TStringList;
    FCurrPosIndex: integer;
    FMoveTime: integer;
    FValidator: TValidator;
    FDragging: boolean;
    FMousePos, FDragPos, FInitPos: TPoint;
    FPieceIndex: integer;
    FCastlingFlag: boolean;
    FWaitingForAnimationEnd: boolean;
    FWaitingForReadyOk: integer;
    FWaitingForUserMove: boolean;
    procedure HandleKeyPress(var KeyCode: word; var ShiftState: TShiftState; var Consumed: boolean); override;
  public
    destructor Destroy; override;
    procedure AfterCreate; override;
    procedure InitForm;
    procedure WidgetPaint(Sender: TObject);
    procedure WidgetMouseDown(Sender: TObject; AButton: TMouseButton; AShift: TShiftState; const AMousePos: TPoint);
    procedure WidgetMouseEnter(Sender: TObject);
    procedure WidgetMouseExit(Sender: TObject);
    procedure WidgetMouseMove(Sender: TObject; AShift: TShiftState; const AMousePos: TPoint);
    procedure WidgetMouseUp(Sender: TObject; AButton: TMouseButton; AShift: TShiftState; const AMousePos: TPoint);
  private
{@VFD_HEAD_BEGIN: MainForm}
    FChessboardWidget: TfpgWidget;
    FStatusBar: TfpgPanel;
    FMenuBar: TfpgMenuBar;
    FEschecsSubMenu: TfpgPopupMenu;
    FMovesSubMenu: TfpgPopupMenu;
    FBoardSubMenu: TfpgPopupMenu;
    FOptionsSubMenu: TfpgPopupMenu;
    FAudioSubMenu: TfpgPopupMenu;
    FStyleSubMenu: TfpgPopupMenu;
    FLanguageSubMenu: TfpgPopupMenu;
    FPromotionSubMenu: TfpgPopupMenu;
{@VFD_HEAD_END: MainForm}
    FTimer: TfpgTimer;
    procedure ItemExitClicked(Sender: TObject);
    procedure ItemNewGameClicked(Sender: TObject);
    procedure ItemStyleClicked(Sender: TObject);
    procedure ItemLanguageClicked(Sender: TObject);
    procedure OtherItemClicked(Sender: TObject);
    procedure InternalTimerFired(Sender: TObject);
    function DoMove(const aMove: string; const aPromotion: TChessPieceKindEx = cpkNil; aIsComputerMove: boolean = true): boolean;
    procedure OnMoveDone(const aHistory: string; const aSound: boolean = TRUE);
    procedure OnComputerMove;
    procedure OnUserIllegalMove;
    procedure SetComputerColor(const aAutoPlayEnabled: boolean);
    procedure NewPosition(const aPosition: string = FENSTARTPOSITION; const aHistory: string = '');
    function TryNavigate(const aCurrentIndex: integer; const aNavigation: TNavigation): integer;
{$IFDEF OPT_SOUND}
    procedure PlaySound(const aSound: integer);
{$ENDIF}
    procedure CloseAll(Sender: TObject);
    procedure SaveGame(Sender: TObject);
    procedure OnResized(Sender: TObject);
  end;

{@VFD_NEWFORM_DECL}
{@VFD_NEWFORM_IMPL}

{$I icon.inc}

const
  FIRST_ENGINE_ITEM_INDEX = 3;

var
  vListener: TThread;
  
  {$IFDEF OPT_DEBUG}
  vUCILog: text;
  {$ENDIF}
  vColoring: boolean;

{$IFDEF OPT_DEBUG}
 procedure UCILogAppend(const aText, aInsert: string);
var
  vList: TStringList;
  vLine, vDateTime: string;
begin
  vList := TStringList.Create;
  ExtractStrings([#10, #13], [' '], PChar(aText), vList);
  vDateTime := DateTimeToStr(Now());
  for vLine in vList do
    WriteLn(vUCILog, vDateTime, ' ', aInsert, ' ', vLine);
  Flush(vUCILog);
  vList.Free;
end;
  {$ENDIF}

procedure WriteProcessInput_(const aUciCommand: string);
begin
  WriteProcessInput(aUciCommand);
  {$IFDEF OPT_DEBUG}
   UCILogAppend(aUciCommand, '<');
  {$ENDIF}
end;

function ArbitratorMessage(const aCheck: boolean; const aActiveColor: TChessPieceColor; const aState: TChessState): string;
begin
  case aState of
    csProgress:
        result := Concat(
          IfThen(aCheck, Concat(GetText(txCheck), ' '), ''),
          IfThen(aActiveColor = cpcWhite, GetText(txWhiteToMove), GetText(txBlackToMove))
        );
    csCheckmate:
        result := Concat(
          GetText(txCheckmate), ' ',
          IfThen(aActiveColor = cpcWhite, GetText(txBlackWins), GetText(txWhiteWins))
        );
    csStalemate:
      result := GetText(txStalemate);
    csDraw:
      result := GetText(txDraw);
  end;
end;

procedure TMainForm.HandleKeyPress(var KeyCode: word; var ShiftState: TShiftState; var Consumed: boolean);
begin
  case KeyCode of
    KeyLeft, KeyBackspace:
      FCurrPosIndex := TryNavigate(FCurrPosIndex, nvPrevious);
    KeyRight:
      FCurrPosIndex := TryNavigate(FCurrPosIndex, nvNext);
    KeyUp:
      FCurrPosIndex := TryNavigate(FCurrPosIndex, nvLast);
    KeyDown:
      FCurrPosIndex := TryNavigate(FCurrPosIndex, nvFirst);
  end;
end;

destructor TMainForm.Destroy;
begin
  FBGRAChessboard.Free;
  FGame.Free;
  if FEngineConnected then
  begin
    WriteProcessInput_(MsgQuit());
    FreeConnectedProcess;
    vListener.Terminate;
    vListener.WaitFor;
  end;
  vListener.Free;
  FMoveHistory.Free;
  FPositionHistory.Free;
  FValidator.Free;
  FreePictures;
  FChessboardWidget.Free;
  FTimer.Free;
  inherited Destroy;
end;

procedure TMainForm.AfterCreate;
begin
{%region 'Auto-generated GUI code' -fold}
{@VFD_BODY_BEGIN: MainForm}
  Name := 'MainForm';
  SetPosition(351, 150, 640, 495);
  WindowTitle := 'Eschecs';
  BackGroundColor := $80000001;
  Hint := '';
  IconName := 'vfd.eschecs';
  WindowPosition := wpOneThirdDown;
  OnResize := @onresized;
  FChessboardWidget := TfpgWidget.Create(self);
  with FChessboardWidget do
  begin
    Name := 'FChessboardWidget';
    SetPosition(0, 0, 640, 472);
    BackgroundColor := clNone;
    OnPaint := @WidgetPaint;
    OnMouseDown := @WidgetMouseDown;
    OnMouseUp := @WidgetMouseUp;
    OnMouseMove := @WidgetMouseMove;
    OnMouseEnter := @WidgetMouseEnter;
    OnMouseExit := @WidgetMouseExit;
  end;
  FStatusBar := TfpgPanel.Create(self);
  with FStatusBar do
  begin
    Name := 'FStatusBar';
    SetPosition(0, 471, 640, 24);
    Align := alBottom;
    Alignment := taLeftJustify;
    BackgroundColor := TfpgColor($FFFFFF);
    FontDesc := '#Label1';
    ParentShowHint := False;
    Style := bsLowered;
    Text := '';
    TextColor := TfpgColor($000000);
    Hint := '';
  end;
  FMenuBar := TfpgMenuBar.Create(self);
  with FMenuBar do
  begin
    Name := 'FMenuBar';
    SetPosition(0, 0, 640, 28);
    Align := alTop;
  end;
  FEschecsSubMenu := TfpgPopupMenu.Create(self);
  with FEschecsSubMenu do
  begin
    Name := 'FEschecsSubMenu';
    SetPosition(68, 56, 228, 28);
  end;
  FMovesSubMenu := TfpgPopupMenu.Create(self);
  with FMovesSubMenu do
  begin
    Name := 'FMovesSubMenu';
    SetPosition(80, 272, 228, 28);
  end;
  FBoardSubMenu := TfpgPopupMenu.Create(self);
  with FBoardSubMenu do
  begin
    Name := 'FBoardSubMenu';
    SetPosition(76, 220, 228, 28);
  end;
  FOptionsSubMenu := TfpgPopupMenu.Create(self);
  with FOptionsSubMenu do
  begin
    Name := 'FOptionsSubMenu';
    SetPosition(72, 172, 228, 28);
  end;
{$IFDEF OPT_SOUND}
  FAudioSubMenu := TfpgPopupMenu.Create(self);
  with FAudioSubMenu do
  begin
    Name := 'FAudioSubMenu';
    SetPosition(68, 168, 228, 28);
  end;
{$ENDIF}
  FStyleSubMenu := TfpgPopupMenu.Create(self);
  with FStyleSubMenu do
  begin
    Name := 'FStyleSubMenu';
    SetPosition(92, 388, 228, 28);
  end;
  FLanguageSubMenu := TfpgPopupMenu.Create(self);
  with FLanguageSubMenu do
  begin
    Name := 'FLanguageSubMenu';
    SetPosition(92, 332, 228, 28);
  end;
  FPromotionSubMenu := TfpgPopupMenu.Create(self);
  with FPromotionSubMenu do
  begin
    Name := 'FPromotionSubMenu';
    SetPosition(68, 112, 228, 28);
  end;
{@VFD_BODY_END: MainForm}
{%endregion}
  InitForm;
end;

procedure TMainForm.InitForm;
const
  MENU_BAR_HEIGHT = 24;
var
  vCurrentPosition: string;
  vAutoPlay, vMarble: boolean;
  vIndex: integer;
  vENGPath: TFileName;
  vLang: TLanguage;
  vMoveHistory: string;
begin
  vENGPath := vConfigFilesPath + 'eschecs.eng';
  if FileExists(vENGPath) then LoadEnginesDataFromINI(vENGPath);
  ReadFromINIFile(vCurrentPosition, vAutoPlay, FUpsideDown, vMarble, FExePath, vMoveHistory,
  FCurrPosIndex, FEngine, vLightSquareColor, vDarkSquareColor, vSpecialColors[ocGreen],
  vSpecialColors[ocRed], FMoveTime, vReplaceFont);
  ReadStyle(gStyle);
  ReadLanguage(gLanguage);
  ReadColoring(vColoring);
  FValidator := TValidator.Create;
  Assert(FValidator.IsFEN(vCurrentPosition));
  FMoveHistory := TMoveList.Create(vMoveHistory);
  FPositionHistory := TStringList.Create;
  if FileExists(vFENPath) then
    FPositionHistory.LoadfromFile(vFENPath)
  else
    FPositionHistory.Append(FENSTARTPOSITION);
  with FMenuBar do
  begin
    AddMenuItem(GetText(txEschecs), nil).SubMenu := FEschecsSubMenu;
    AddMenuItem(GetText(txMoves), nil).SubMenu := FMovesSubMenu;
    AddMenuItem(GetText(txBoard), nil).SubMenu := FBoardSubMenu;
    AddMenuItem(GetText(txOptions), nil).SubMenu := FOptionsSubMenu;
    AddMenuItem(GetText(txPromotion), nil).SubMenu := FPromotionSubMenu;
  end;
  with FEschecsSubMenu do
  begin
    AddMenuItem(GetText(txSave), 'Ctrl+S', @savegame);
    AddMenuItem(GetText(txSave) + ' + ' + GetText(txquit), 'Esc', @ItemExitClicked);
    AddMenuItem('-', '', nil);
    AddMenuItem(GetText(txQuit), 'Ctrl+Q', @closeall);
    AddMenuItem('-', '', nil);
    AddMenuItem(GetText(txAbout), '', @OtherItemClicked);
  end;
  with FOptionsSubMenu do
  begin
    AddMenuItem(GetText(txStyle), '',nil).SubMenu := FStyleSubMenu;
    AddMenuItem(GetText(txLanguage), '', nil).SubMenu := FLanguageSubMenu;
{$IFDEF OPT_SOUND}
    AddMenuItem(GetText(txSound), '', nil).SubMenu := FAudioSubMenu;
{$ENDIF}
    AddMenuItem(GetText(txColoring), '', @OtherItemClicked).Checked := vColoring;
  end;
  with FStyleSubMenu do
    for vIndex := Low(TStyle) to High(TStyle) do
      AddMenuItem(GetStyleName(vIndex), '', @ItemStyleClicked).Checked := vIndex = gStyle;
  with FLanguageSubMenu do
    for vLang := Low(TLanguage) to High(TLanguage) do
      AddMenuItem(GetLanguageName(vLang), '', @ItemLanguageClicked).Checked := vLang = gLanguage;
{$IFDEF OPT_SOUND}
  with FAudioSubMenu do
  begin
    AddMenuItem(GetText(txEnabled), '', @OtherItemClicked).Checked := true;
    AddMenuItem('-', '', nil);
    AddMenuItem(GetText(txVolume) + ':', '', nil);
    AddMenuItem('100 %', '', @OtherItemClicked).Checked := true;
    AddMenuItem('75 %', '', @OtherItemClicked).Checked := false;
    AddMenuItem('50 %', '', @OtherItemClicked).Checked := false;
    AddMenuItem('25 %', '', @OtherItemClicked).Checked := false;
  end;
{$ENDIF}
  with FBoardSubMenu do
  begin
    AddMenuItem(GetText(txNew), '', @ItemNewGameClicked);
    AddMenuItem(GetText(txFlip), '', @OtherItemClicked);
  end;
  with FMovesSubMenu do
  begin
    AddMenuItem(GetText(txComputerMove), '', @OtherItemClicked);
    AddMenuItem(GetText(txAutoPlay), '', @OtherItemClicked).Checked := vAutoPlay;
    AddMenuItem('-', '', nil);
    for vIndex := 0 to High(vEngines) do with AddMenuItem(vEngines[vIndex].vName, '', @OtherItemClicked) do
    begin
     Enabled := vEngines[vIndex].vExists;
     Checked := FALSE;
     if (FEngine = -1) and (Pos(UpperCase('Fruit'), UpperCase(vEngines[vIndex].vName)) > 0) then
       FEngine := vIndex;
    end;
  end;
  with FPromotionSubMenu do
  begin
    AddMenuItem(GetText(txKnight), '', @OtherItemClicked).Checked := FALSE;
    AddMenuItem(GetText(txBishop), '', @OtherItemClicked).Checked := FALSE;
    AddMenuItem(GetText(txRook), '', @OtherItemClicked).Checked := FALSE;
    AddMenuItem(GetText(txQueen), '', @OtherItemClicked).Checked := TRUE;
  end;
  SetPosition(0, 0, 8 * gStyleData[gStyle].scale, 24 + 8 * gStyleData[gStyle].scale + 24);
  WindowTitle := DEFAULT_TITLE + ' ' + OSTYPE;
  MinWidth := 8 * gStyleData[gStyle].scale;
  MinHeight := 24 + 8 * gStyleData[gStyle].scale + 24;
  FChessboardWidget.SetPosition(0, MENU_BAR_HEIGHT, 8 * gStyleData[gStyle].scale, 8 * gStyleData[gStyle].scale);
  FStatusBar.SetPosition(0, 24 + 8 * gStyleData[gStyle].scale, 8 * gStyleData[gStyle].scale, 24);
  FMenuBar.SetPosition(0, 0, 8 * gStyleData[gStyle].scale, 24);
  CreatePictures;
  FBoardStyle := TBoardStyle(Ord(vMarble));
  FBGRAChessboard := TBGRAChessboard.Create(FBoardStyle, FUpsideDown, vCurrentPosition);
  FGame := TChessGame.Create(vCurrentPosition);
  FUserMove := '';
  FRookMove := '';
  OnMoveDone(FMoveHistory.GetString(FCurrPosIndex), FALSE);
  SetComputerColor(FMovesSubMenu.MenuItem(1).Checked);
  vListener := TListener.Create(TRUE);
  vListener.Priority := tpHigher;
  FWaiting := FALSE;
  FEngineConnected := FALSE;
  FCastlingFlag := FALSE;
  FWaitingForAnimationEnd := FALSE;
  FWaitingForReadyOk := 0;
  FWaitingForUserMove := TRUE;
  TLog.Append(Format('Eschecs %s %s %s FPC %s', [VERSION, {$I %DATE%}, {$I %TIME%}, {$I %FPCVERSION%}]));
  TLog.Append(Format('Eschecs %s %s %s FPC %s', [VERSION + ' ' + OSTYPE, {$I %DATE%}, {$I %TIME%}, {$I %FPCVERSION%}]));
  FTimer := TfpgTimer.Create(10);
  FTimer.OnTimer := @InternalTimerFired;
  FTimer.Enabled := TRUE;
  with FMovesSubMenu do if MenuItem(FEngine + FIRST_ENGINE_ITEM_INDEX).Enabled then
    OtherItemClicked(MenuItem(FEngine + FIRST_ENGINE_ITEM_INDEX))
  else
  begin
{$IFDEF OPT_DEBUG}
    WriteLn('MenuItem(1).Checked=', MenuItem(1).Checked);
    WriteLn('MenuItem(', FEngine + FIRST_ENGINE_ITEM_INDEX,').Enabled=', MenuItem(FEngine + FIRST_ENGINE_ITEM_INDEX).Enabled);
{$ENDIF}
  end;

{$IFDEF OPT_SOUND}
 if LoadSoundLib() < 0 then
  begin
   ShowMessagefrm('Sound libraries did not load', 'Audio will be disabled', 'Warning...', GetText(txQuit), '');
   FAudioSubMenu.MenuItem(0).Checked := FALSE;
   FAudioSubMenu.MenuItem(0).enabled := FALSE;
  end
  else 
  begin
  FAudioSubMenu.MenuItem(0).Checked := true;
  FAudioSubMenu.MenuItem(0).enabled := true;
  end;
{$ENDIF}
end;

procedure TMainForm.WidgetPaint(Sender: TObject);
begin
  with FBGRAChessboard do
    DrawToFPGCanvas(FChessboardWidget.Canvas, 0, 0);
end;

procedure TMainForm.WidgetMouseDown(Sender: TObject; AButton: TMouseButton; AShift: TShiftState; const AMousePos: TPoint);
var
  X, Y: integer;
begin
  if (FGame.state = csProgress) and FWaitingForUserMove then
  begin
    FMousePos := AMousePos;
    FDragPos.X := AMousePos.X mod gStyleData[gStyle].scale;
    FDragPos.Y := AMousePos.Y mod gStyleData[gStyle].scale;
    FInitPos := AMousePos - FDragPos;
    FBGRAChessboard.ScreenToXY(AMousePos, X, Y);
    FPieceIndex := FBGRAChessboard.FindPiece(X, Y, TChessPieceColor(Ord(FGame.ActiveColor)));
    if FPieceIndex > 0 then
    begin
      FUserMove := EncodeSquare(X, Y);
      FDragging := True;
      FBGRAChessboard.SavePieceBackground(FInitPos, TRUE);
      if vColoring then
        FBGRAChessboard.ScreenRestore;
    end;
  end;
end;

procedure TMainForm.WidgetMouseEnter(Sender: TObject);
begin
  //TfpgWidget(Sender).MouseCursor := mcHand;
end;

procedure TMainForm.WidgetMouseExit(Sender: TObject);
begin
  //TfpgWidget(Sender).MouseCursor := mcDefault;
end;

procedure TMainForm.WidgetMouseMove(Sender: TObject; AShift: TShiftState; const AMousePos: TPoint);
var
  X, Y: integer;
begin
  if FDragging then
  begin
    FBGRAChessboard.RestorePieceBackground(FMousePos - FDragPos);
    FBGRAChessboard.SavePieceBackground(AMousePos - FDragPos);
    FBGRAChessboard.DrawPiece(AMousePos - FDragPos, FPieceIndex);
    FChessboardWidget.Invalidate;
    FMousePos := AMousePos;
  end else
  begin
    FBGRAChessboard.ScreenToXY(AMousePos, X, Y);
    if FWaitingForUserMove and (FBGRAChessboard.FindPiece(X, Y, TChessPieceColor(Ord(FGame.ActiveColor))) > 0) then
      TfpgWidget(Sender).MouseCursor := mcHand
    else
      TfpgWidget(Sender).MouseCursor := mcDefault;
  end;
end;

procedure TMainForm.WidgetMouseUp(Sender: TObject; AButton: TMouseButton; AShift: TShiftState; const AMousePos: TPoint);
var
  vPromotion: TChessPieceKind;
  X, Y: integer;
begin
{$IFDEF OPT_DEBUG}
  WriteLn('TMainForm.WidgetMouseUp()');
{$ENDIF}
  if not FDragging then
    Exit;
  FDragging := False;
  FBGRAChessboard.ScreenToXY(AMousePos, X, Y);
  FUserMove := Concat(FUserMove, EncodeSquare(X, Y));
  if FGame.IsLegal(FUserMove) then
  begin
    if      FPromotionSubMenu.MenuItem(0).Checked then vPromotion := cpkKnight
    else if FPromotionSubMenu.MenuItem(1).Checked then vPromotion := cpkBishop
    else if FPromotionSubMenu.MenuItem(2).Checked then vPromotion := cpkRook
    else if FPromotionSubMenu.MenuItem(3).Checked then vPromotion := cpkQueen;
    FBGRAChessboard.RestorePieceBackground(FMousePos - FDragPos);
    if DoMove(FUserMove, vPromotion, FALSE) then
      FBGRAChessboard.SetPieceKind(FPieceIndex, vPromotion);
    FBGRAChessboard.SetPieceXY(FPieceIndex, X, Y);
    FBGRAChessboard.DrawPiece(FBGRAChessboard.XYToScreen(X, Y), FPieceIndex);
    if vColoring then
    begin
      if FCastlingFlag then
        FCastlingFlag := FALSE
      else
      begin
        FBGRAChessboard.ScreenSave;
        FBGRAChessboard.HighlightMove(FUserMove, FPieceIndex);
      end;
    end;
    FChessboardWidget.Invalidate;
    OnMoveDone(FMoveHistory.GetString(FCurrPosIndex));
  end else
  begin
    FBGRAChessboard.RestorePieceBackground(FMousePos - FDragPos);
    FBGRAChessboard.DrawPiece(FInitPos, FPieceIndex);
    FChessboardWidget.Invalidate;
    if Copy(FUserMove, 3, 2) <> Copy(FUserMove, 1, 2) then
      OnUserIllegalMove;
  end;
end;

procedure TMainForm.ItemExitClicked(Sender: TObject);
begin
  SaveGame(Sender);
  Close;
end;

procedure TMainForm.ItemNewGameClicked(Sender: TObject);
begin
  NewPosition(FENSTARTPOSITION);
  FMoveHistory.Clear;
  FPositionHistory.Clear;
  FPositionHistory.Append(FENSTARTPOSITION);
  FCurrPosIndex := 0;
  FWaitingForUserMove := TRUE;
end;

procedure TMainForm.ItemStyleClicked(Sender: TObject);
const
  FIRST_ITEM_INDEX = 2;
var
  vStyle: TStyle;
  vSelectedStyle: TStyle = 0;
begin
  for vStyle := Low(TStyle) to High(TStyle) do if GetStyleName(vStyle) = TfpgMenuItem(Sender).Text then
    vSelectedStyle := vStyle;
{$IFDEF OPT_DEBUG}
  WriteLn('vSelectedStyle = ', vSelectedStyle);
{$ENDIF}
  for vStyle := Low(TStyle) to High(TStyle) do
    FStyleSubMenu.MenuItem(Ord(vStyle)).Checked := vStyle = vSelectedStyle;
  ShowMessagefrm(GetText(txChangeSaved), '',  GetText(txTitleMessage), GetText(txQuit), '');
  WriteStyle(vSelectedStyle);
end;

procedure TMainForm.ItemLanguageClicked(Sender: TObject);
var
  vLanguage: TLanguage;
  vSelectedLanguage: TLanguage;
begin
  for vLanguage := Low(TLanguage) to High(TLanguage) do if GetLanguageName(vLanguage) = TfpgMenuItem(Sender).Text then
    vSelectedLanguage := vLanguage;
{$IFDEF OPT_DEBUG}
  WriteLn('vSelectedLanguage = ', vSelectedLanguage);
{$ENDIF}
  for vLanguage := Low(TLanguage) to High(TLanguage) do
    FLanguageSubMenu.MenuItem(Ord(vLanguage)).Checked := vLanguage = vSelectedLanguage;
  ShowMessagefrm(GetText(txChangeSaved), '',  GetText(txTitleMessage), GetText(txQuit), '');
  WriteLanguage(vSelectedLanguage);
end;

procedure TMainForm.OtherItemClicked(Sender: TObject);
var
  i, j: integer;
begin
  if Sender is TfpgMenuItem then
    with TfpgMenuItem(Sender) do
      if Text = GetText(txAbout) then
      ShowMessagefrm('Eschecs ' + VERSION + ' ' + OSTYPE, GetText(txAboutMessage), GetText(txAbout), GetText(txQuit), 'Eschecs on Github.')
    else
      if Text = GetText(txComputerMove) then
        FComputerColor := FGame.ActiveColor
      else
      if Text = GetText(txAutoPlay) then
      begin
        Checked := not Checked;
        SetComputerColor(Checked);
      end else
      if Text = GetText(txFlip) then
      begin
        FBGRAChessboard.ScreenRestore;
        FBGRAChessboard.FlipBoard;
        FChessboardWidget.Invalidate;
        FBGRAChessboard.ScreenSave;
        FUpsideDown := FBGRAChessboard.isUpsideDown;
      end else
      if Text = GetText(txColoring)
      then
      begin
        Checked := not Checked;
        vColoring := Checked;
        WriteColoring(vColoring);
        ShowMessagefrm(GetText(txChangeSaved), '',  GetText(txTitleMessage), GetText(txQuit), '');
      end
      else
{$IFDEF OPT_SOUND}
      if Text = GetText(txEnabled)
      then
      begin
        Checked := not Checked;
      end
      else
      if Text = '100 %'
      then
      begin
          for i := 3 to 6 do
           FAudioSubMenu.MenuItem(i).Checked := FALSE;
          Checked := TRUE;
          SetSoundVolume(100);
      end
      else
      if Text = '75 %'
      then
      begin
          for i := 3 to 6 do
          FAudioSubMenu.MenuItem(i).Checked := FALSE;
          Checked := TRUE;
          SetSoundVolume(75);
      end
      else
      if Text = '50 %'
      then
      begin
          for i := 3 to 6 do
          FAudioSubMenu.MenuItem(i).Checked := FALSE;
          Checked := TRUE;
          SetSoundVolume(50);
      end
      else
      if Text = '25 %'
      then
      begin
          for i := 3 to 6 do
          FAudioSubMenu.MenuItem(i).Checked := FALSE;
          Checked := TRUE;
          SetSoundVolume(25);
      end
      else
{$ENDIF}
      if (Text = GetText(txKnight))
      or (Text = GetText(txBishop))
      or (Text = GetText(txRook))
      or (Text = GetText(txQueen)) then
      begin
        for i := 0 to 3 do
          FPromotionSubMenu.MenuItem(i).Checked := FALSE;
        Checked := TRUE;
      end else
      for i := 0 to High(vEngines) do
        if Text = vEngines[i].vName then
        begin
          for j := 0 to High(vEngines) do
            FMovesSubMenu.MenuItem(j + FIRST_ENGINE_ITEM_INDEX).Checked := j = i;
          if FEngineConnected then
          begin
            WriteProcessInput_(MsgQuit());
            FreeConnectedProcess;
          end;
          FEngineConnected :=
            FileExists(Concat(vEngines[i].vDirectory, vEngines[i].vCommand))
            and SetCurrentDir(vEngines[i].vDirectory)
            and CreateConnectedProcess(vEngines[i].vCommand);
          if FEngineConnected then
          begin
            TLog.Append('Connexion établie.');
            vListener.Start;
            WriteProcessInput_(MsgUCI());
            FEngine := i;
          end else
            ShowMessagefrm(GetText(txConnectionFailure), '',  GetText(txTitleMessage), GetText(txQuit), '');
        end;
end;

procedure TMainForm.InternalTimerFired(Sender: TObject);
var
  vAnimationTerminated: boolean;
begin
  if FBGRAChessboard.Animate(vAnimationTerminated) then
    FChessboardWidget.Invalidate
  else
    if FRookMove <> '' then
    begin
      FBGRAChessboard.MovePiece(FRookMove);
      FRookMove := '';
    end else
      if FEngineConnected
      and (FComputerColor = FGame.ActiveColor)
      and (FGame.state = csProgress)
      and not FWaiting then
      begin
{$IFDEF OPT_DEBUG}
        WriteLn('FWaitingForReadyOk = ', FWaitingForReadyOk);
{$ENDIF}
        case FWaitingForReadyOk of
          0:
            begin
              FWaitingForReadyOk := 1;
              WriteProcessInput_(MsgPosition(FGame.FENRecord));
              WriteProcessInput_(MsgIsReady());
            end;
          1:
            begin
            end;
          2:
            begin
              FWaitingForReadyOk := 0;
              WriteProcessInput_(MsgGo(FMoveTime));
              MouseCursor := mcHourGlass;
              FWaiting := TRUE;
              FStatusBar.Text := Concat(' ', GetText(txWaiting));
              FWaitingForUserMove := FALSE;
            end;
        end;
      end;

  if FWaitingForAnimationEnd and vAnimationTerminated then
  begin
    FWaitingForAnimationEnd := FALSE;
    OnComputerMove;
  end;
end;

function TMainForm.DoMove(const aMove: string; const aPromotion: TChessPieceKindEx; aIsComputerMove: boolean = true): boolean;
const
  SYMBOLS: array[cpkKnight..cpkQueen] of char = ('n', 'b', 'r', 'q');
var
  vX, vY: integer;
  vSquare: string;
  vPromotion: TChessPieceKind;
  vSymbol: string;
begin
{$IFDEF OPT_DEBUG}
  WriteLn(Format('TMainForm.DoMove(%s, %s, %s)', [
    aMove,
    GetEnumName(TypeInfo(TChessPieceKindEx), Ord(aPromotion)),
    BoolToStr(aIsComputerMove, TRUE)
  ]));
{$ENDIF}
  vSquare := Copy(aMove, 3, 2);
  DecodeSquare(vSquare, vX, vY);
  if FBGRAChessboard.FindPiece(vX, vY) > 0 then
    FBGRAChessboard.ErasePiece(vSquare);

  vSquare := FGame.IsEnPassant(aMove);
  if vSquare <> '' then
    FBGRAChessboard.ErasePiece(vSquare);

  result := FGame.IsPromotion(aMove);
  if result then
  begin
    vPromotion := ValidPromotionValue(aPromotion);
    vSymbol := SYMBOLS[vPromotion];
    if aIsComputerMove then
      FBGRAChessboard.MovePiece(aMove, TRUE, vPromotion);
    vMoveToBeHighlighted := aMove;
  end else
  begin
    vSymbol := '';
    FRookMove := FGame.IsCastling(aMove);
    if vColoring then
    begin
      FCastlingFlag := Length(FRookMove) > 0;
      vMoveToBeHighlighted := aMove;
      vComputerCastlingFlag := FCastlingFlag and aIsComputerMove;
      if FCastlingFlag then
      begin
        DecodeSquare(Copy(aMove, 1, 2), vX, vY);
        vKingIndex := FBGRAChessboard.FindPiece(vX, vY);
      end;
    end;
    if aIsComputerMove then
      FBGRAChessboard.MovePiece(aMove, FALSE);
  end;

  FGame.PlayMove(Concat(aMove, vSymbol));

  FMoveHistory.Append(aMove, FCurrPosIndex);
  while FPositionHistory.Count > Succ(FCurrPosIndex) do
    FPositionHistory.Delete(FPositionHistory.Count - 1);
  FPositionHistory.Append(FGame.FENRecord);
  Inc(FCurrPosIndex);
end;

procedure TMainForm.OnMoveDone(const aHistory: string; const aSound: boolean);
var
  vX, vY: integer;
  vIndex: integer;
  vOpeningName: string;
begin
{$IFDEF OPT_DEBUG}
  WriteLn('TMainForm.OnMoveDone()');
{$ENDIF}
  if vColoring and FGame.Check and FBGRAChessboard.ScreenSaved() then
  begin
    FGame.GetKingCheckedXY(vX, vY);
    vIndex := FBGRAChessboard.FindPiece(vX, vY);
    FBGRAChessboard.Highlight(vX, vY, ocRed, vIndex);
    FChessboardWidget.Invalidate;
  end;
{$IFDEF OPT_SOUND}
    if aSound then
      if FGame.state in [csCheckmate, csStalemate, csDraw] then
        PlaySound(sndEndOfGame)
      else if FGame.Check then
        PlaySound(sndCheck)
      else if FALSE then // <--- to do
        PlaySound(sndPromotion)
      else if FALSE then // <--- to do
        PlaySound(sndCapture)
      else
        PlaySound(sndMove);
{$ENDIF}
  FStatusBar.Text := Concat(' ', ArbitratorMessage(FGame.Check, FGame.ActiveColor, FGame.state));
  
   if FGame.state in [csCheckmate, csStalemate, csDraw] then
        FStatusBar.BackgroundColor := $FFF692
      else if FGame.Check then
       FStatusBar.BackgroundColor := $FFB3B8
      else if FALSE then // <--- to do
         FStatusBar.BackgroundColor := $E9FFC8
      else if FALSE then // <--- to do
        FStatusBar.BackgroundColor := $FFF692
      else
        FStatusBar.BackgroundColor := $FFFFFF;
  
{$IFDEF OPT_ECO}
  vOpeningName := ECO.GetOpening(aHistory);
  if Length(vOpeningName) > 0 then
    TLog.Append(Format('Ouverture "%s".', [vOpeningName]));
{$ENDIF}
  FWaitingForUserMove := not (FGame.state in [csCheckmate, csStalemate, csDraw]);
end;

procedure TMainForm.OnComputerMove;
begin
  if not FMovesSubMenu.MenuItem(1).Checked then
    FComputerColor := cpcNil;
  MouseCursor := mcHand;
  OnMoveDone(FMoveHistory.GetString(FCurrPosIndex));
  FWaiting := FALSE;
  FWaitingForUserMove := TRUE;
end;

procedure TMainForm.OnUserIllegalMove;
begin
{$IFDEF OPT_SOUND}
  PlaySound(sndIllegal);
{$ENDIF}
end;

procedure TMainForm.SetComputerColor(const aAutoPlayEnabled: boolean);
begin
  if aAutoPlayEnabled then
    FComputerColor := TChessPieceColor(1 - Ord(FGame.ActiveColor))
  else
    FComputerColor := cpcNil;
end;

procedure TMainForm.NewPosition(const aPosition: string; const aHistory: string);
begin
  FBGRAChessboard.Free;
  FBGRAChessboard := TBGRAChessboard.Create(FBoardStyle, FUpsideDown, aPosition);
  FGame.Create(aPosition);
  OnMoveDone(aHistory, FALSE);
  SetComputerColor(FMovesSubMenu.MenuItem(1).Checked);
  FChessboardWidget.Invalidate;
  FStatusBar.BackgroundColor := $FFFFFF;
end;

function TMainForm.TryNavigate(const aCurrentIndex: integer; const aNavigation: TNavigation): integer;
begin
  result := aCurrentIndex;
  case aNavigation of
    nvPrevious:
      if aCurrentIndex > 0 then
        result := Pred(aCurrentIndex);
    nvNext:
      if aCurrentIndex < Pred(FPositionHistory.Count) then
        result := Succ(aCurrentIndex);
    nvLast:
      if aCurrentIndex < Pred(FPositionHistory.Count) then
        result := Pred(FPositionHistory.Count);
    nvFirst:
      if aCurrentIndex > 0 then
        result := 0;
  end;
  if result <> aCurrentIndex then
    NewPosition(
      FPositionHistory[result],
      IfThen(
        result = 0,
        '',
        FMoveHistory.GetString(result)
      )
    );
end;

{$IFDEF OPT_SOUND}
procedure TMainForm.PlaySound(const aSound: integer);
begin
 if FAudioSubMenu.MenuItem(0).Checked then
   Play(aSound);
end;
{$ENDIF}

procedure TMainForm.CloseAll(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.SaveGame(Sender: TObject);
var
  vMoveHist: string;
begin
{$IFDEF OPT_DEBUG}
  WriteLn('SaveGame()');
{$ENDIF}
  vMoveHist := FMoveHistory.GetString();
  WriteToINIFile(
    FGame.FENRecord,
    FMovesSubMenu.MenuItem(1).Checked,
    FUpsideDown,
    FBoardStyle = bsMarble,
    FExePath,
    vMoveHist,
    FCurrPosIndex,
    FEngine,
    vLightSquareColor, vDarkSquareColor, vSpecialColors[ocGreen], vSpecialColors[ocRed],
    FMoveTime,
    vReplaceFont
  );
  FPositionHistory.SaveToFile(vFENPath);
end;

procedure TMainForm.OnResized(Sender: TObject);
begin
 FChessboardWidget.top := (height -FChessboardWidget.height) div 2;
 FChessboardWidget.left := (width - FChessboardWidget.width) div 2;
 FChessboardWidget.updatewindowposition;
end;

var
  frm: TMainForm;

procedure TListener.Execute;
const
  DELAY = 100;
begin
  while not Terminated do
  begin
    FEngineMessage := ReadProcessOutput; if FEngineMessage <> '' then Synchronize(@OnEngineMessage);
    FEngineMessage := ReadProcessError;  if FEngineMessage <> '' then Synchronize(@OnEngineMessage);
    Sleep(DELAY);
  end;
end;

procedure TListener.OnEngineMessage;
var
  vName, vAuthor, vMove, vPromotion: string;
  vPieceKind: TChessPieceKindEx;
begin
{$IFDEF OPT_DEBUG}
 UCILogAppend(FEngineMessage, '>');
{$ENDIF}

  if IsMsgUciOk(FEngineMessage, vName, vAuthor) then
   begin
    TLog.Append(Format('Protocole accepté. Moteur "%s". Auteur "%s".', [vName, vAuthor]));
    //WriteProcessInput_(MsgNewGame());
    frm.WindowTitle := vName;
  end else

  if IsMsgBestMove(FEngineMessage, vMove, vPromotion) then
  begin
    if frm.FGame.IsLegal(vMove) then
    begin
      if Length(vPromotion) = 1 then
        case vPromotion[1] of
          'n': vPieceKind := cpkKnight;
          'b': vPieceKind := cpkBishop;
          'r': vPieceKind := cpkRook;
          'q': vPieceKind := cpkQueen;
        end
      else
        vPieceKind := cpkNil;

      if vColoring then
        frm.FBGRAChessboard.ScreenRestore;
      frm.DoMove(vMove, vPieceKind);
    end else
    begin
      ShowMessagefrm(GetText(txIllegalMove), vMove,  GetText(txTitleMessage), GetText(txQuit), '');
      frm.FMovesSubMenu.MenuItem(1).Checked := FALSE;
      frm.FComputerColor := cpcNil;
    end;
    frm.FWaitingForAnimationEnd := TRUE;
  end else

  if IsMsgReadyOk(FEngineMessage) then
  begin
    Assert(frm.FWaitingForReadyOk = 1);
    frm.FWaitingForReadyOk := 2;
  end;
end;

{$IFDEF OPT_DEBUG}
 var
  vUciLogName: string;
{$ENDIF}  

begin
  fpgApplication.Initialize;
  fpgImages.AddMaskedBMP('vfd.eschecs', @vfd_eschecs, sizeof(vfd_eschecs), 0, 0);
  if fpgStyleManager.SetStyle('eschecs_style') then
    fpgStyle := fpgStyleManager.Style;
  if DirectoryExists(vConfigFilesPath) then
   begin
        
    Assign(vLog, vLOGPath);
    if FileExists(vLOGPath) then
      Append(vLog)
    else
      Rewrite(vLog);
      
    {$IFDEF OPT_DEBUG}
    vUciLogName := Concat(vConfigFilesPath, 'eschecs.debug');
    Assign(vUCILog, vUciLogName);
    if FileExists(vUciLogName) then
      Append(vUCILog)
    else
      Rewrite(vUCILog);
    {$ENDIF} 
      
{$IFDEF OPT_ECO}
    InitEco();
{$ENDIF}
    fpgApplication.CreateForm(TMainForm, frm);
    fpgApplication.MainForm := frm;
      if FileExists(vConfigFilesPath + 'eschecs.eng')
     then else
     begin
    ShowMessagefrm('No /config/eschecs.eng file found.', 'Sorry but no chess engines will be available.', 'Warning', 'Close', '');
    frm.FMovesSubMenu.visible := false;
    frm.FMovesSubMenu.enabled := false;
     end;
    frm.Show;
    fpgApplication.Run;
{$IFDEF OPT_SOUND}
    Freeuos;
{$ENDIF}
    frm.Free;
{$IFDEF OPT_ECO}
    FreeEco();
{$ENDIF}
    Close(vLog);
{$IFDEF OPT_DEBUG}
    Close(vUCILog);
{$ENDIF} 
  end else
  begin
    ShowMessagefrm('The /config folder is missing.', 'Please check your configuration or reinstall Eschecs.', 'Error...', 'Close', 'Eschecs on GitHub.');
  end;
   fpgApplication.Terminate; 
end.

