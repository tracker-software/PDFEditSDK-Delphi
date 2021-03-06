unit PDFInst;

interface
uses
  System.SysUtils, PDFXEdit_TLB, Vcl.Graphics, math, matrix;

type
  TInst = class
  private
    { private declarations }
    function P2X(x, dpi: double):double;
  protected
    { protected declarations }
  public
    { public declarations }
    FInst: PDFXEdit_TLB.IPXV_Inst;
    FInstCore: PDFXEdit_TLB.IPXC_Inst;
    FInstAUX: IAUX_Inst;

    constructor Create;
    destructor Destroy; override;

    procedure Init(inst: PDFXEdit_TLB.IPXV_Inst);
    procedure InsertEmptyPage(doc: PDFXEdit_TLB.IPXV_Document; nPage: integer; nCount: integer);
    procedure DeletePages(doc: PDFXEdit_TLB.IPXV_Document; nPageStart, nPageStop: integer);

    procedure InsertPagesTest();
    procedure BuildPageBitmap(APage: IPXC_Page; var B: TBitmap; ASize: Integer);
    procedure DrawText(ADoc: IPXC_Document);
  published
    { published declarations }
  end;

var
  gInst: TInst;

implementation

{ TInst }

procedure TInst.BuildPageBitmap(APage: IPXC_Page; var B: TBitmap;
  ASize: Integer);
var
  AWidth, AHeight: Double;
  W, H, ADPI: Integer;
  ARect: tagRECT;
  APageMatrix: PXC_Matrix;
  AMatrixRect: PXC_Matrix;
  AFlags: Integer;
  ARenderParams: IPXC_PageRenderParams;
  AOCContext: IPXC_OCContext;
  srcRect: PXC_Rect;
begin
  ADPI := 300;

  if (B.PixelFormat = pfDevice) then B.PixelFormat := pf24bit;

  //Get Page dimensions in Points
  APage.GetDimension(AWidth, AHeight);

  //Make Sure the Image is not Too Big
  if (AHeight > AWidth) then
  begin
    if (P2X(AHeight, 100) > 4400) or (P2X(AWidth, 100) > 3400) then ADPI := 100;
  end else
  begin
    if (P2X(AWidth, 100) > 4400) or (P2X(AHeight, 100) > 3400) then ADPI := 100;
  end;

  //Convert to Pixes
  ADPI := Max(100, ADPI);
  W := Round(P2X(AWidth, ADPI));
  H := Round(P2X(AHeight, ADPI));

  if (ASize <= 0) then ASize := Max(H, W);

  if (H > W) then
  begin
    W := Ceil(ASize * (W / H));
    H := ASize;
  end else
  begin
    H := Ceil(ASize * (H / W));
    W := ASize;
  end;

  with ARect do
  begin
    Left := 0;
    Top := 0;
    Right := Left + W;
    Bottom := Top + H;
  end;

  B.SetSize(W, H);

  //Getting source page matrix
  APage.GetMatrix(PBox_PageBox, APageMatrix);
  AFlags := DDF_AsVector;
  ARenderParams := nil;
  AOCContext := nil;

  //Getting source page Page Box without rotation
  APage.get_Box(PBox_PageBox, srcRect);
  //Getting visual source Page Box by transforming it through matrix
  TransformRect(APageMatrix, srcRect);
  //We'll insert the visual src page into the image rectangle including page rotations and clipping
  AMatrixRect := RectToRectMatrix(srcRect, ARect);
  APageMatrix := Multiply(APageMatrix, AMatrixRect);

  APage.DrawToDevice(B.Canvas.Handle, ARect, APageMatrix, AFlags, ARenderParams, AOCContext, nil);
end;

constructor TInst.Create;
begin
  inherited;
  FInst := nil;
end;

destructor TInst.Destroy;
begin
  FInst := nil;
  inherited;
end;

procedure TInst.DrawText(ADoc: IPXC_Document);
var
  CC: IPXC_ContentCreator;
  Content: IPXC_Content;
  AFont: IPXC_Font;
  AText: String;
  AFontSize, x, y: Double;
  APage: IPXC_Page;
begin
  if Assigned(ADoc) then
  begin
    AFontSize := 15;
    AText := 'TESTING';
    AFont := ADoc.CreateNewFont('Arial', 0, 400);

    ADoc.Pages.Get_Item(0, APage); //Test Page is 612 x 792 points

    //APage.Get_Box();
    //Start roughly in the middle of the page
    x := 100;
    y := 60;

    CC := ADoc.CreateContentCreator;
    CC.SetTextRenderMode(TRM_Fill); //TRM_None;
    CC.SetFont(AFont);
    CC.SetFontSize(AFontSize);
    CC.SetStrokeColorRGB(0); //Black
    CC.ShowTextLine(x, y, PChar(AText), -1, 0);

    CC.Detach(Content);
    APage.PlaceContent(Content, PlaceContent_After);
  end;
end;

procedure TInst.Init(inst: PDFXEdit_TLB.IPXV_Inst);
begin
  FInst := inst;
  FInstCore := FInst.GetExtension('PXC') as PDFXEdit_TLB.IPXC_Inst;
  FInstAUX := FInstCore.GetExtension('AUX') as IAUX_Inst;

end;

procedure TInst.DeletePages(doc: PDFXEdit_TLB.IPXV_Document; nPageStart,
  nPageStop: integer);
var
  nID: integer;
  pOp: PDFXEdit_TLB.IOperation;
  input: PDFXEdit_TLB.ICabNode;
  options: PDFXEdit_TLB.ICabNode;
begin
	nID := FInst.Str2ID('op.document.deletePages', false);
	pOp := FInst.CreateOp(nID);
	input := pOp.Params.Root['Input'];
	input.v := Doc;
	options := pOp.Params.Root['Options'];
	options['PagesRange.Type'].v := 'Exact';
	options['PagesRange.Text'].v := Format('%d-%d', [nPageStart, nPageStop]) ; //Select pages range that will be deleted from the document
	pOp.Do_(0);
end;

procedure TInst.InsertEmptyPage(doc: PDFXEdit_TLB.IPXV_Document; nPage,
  nCount: integer);
var
  nID: integer;
  pOp: PDFXEdit_TLB.IOperation;
  input: PDFXEdit_TLB.ICabNode;
  options: PDFXEdit_TLB.ICabNode;
begin
	nID := FInst.Str2ID('op.document.insertEmptyPages', False);
  pOp := FInst.CreateOp(nID);
  input := pOp.Params.Root['Input'];
	input.v := Doc;
  options := pOp.Params.Root['Options'];
	options['PaperType'].v := 2; //Apply custom paper type
	options['Count'].v := nCount; //Create nCount new pages
	options['Width'].v := 800; //Width of new pages
	options['Height'].v := 1200; //Height of new pages
	options['Location'].v := 1; //New pages will be inserted after first page
	options['Position'].v := nPage; //Page number
	pOp.Do_(0);
end;

procedure TInst.InsertPagesTest;
var
  AFile1, AFile2: String;
  ADoc1, ADoc2: IPXC_Document;
  Apage: IPXC_Page;
  BS: IBitSet;
  APageCount1, APageCount2: Cardinal;
  hr: Cardinal;
  bmp: TBitmap;
begin
  AFile1 := 'c:\tmp\example_images.pdf';
  AFile2 := 'c:\tmp\pagemix.pdf';
  try
    ADoc1 := FInstCore.OpenDocumentFromFile(PChar(AFile1), nil, nil, 0, 0);
    ADoc2 := FInstCore.OpenDocumentFromFile(PChar(AFile2), nil, nil, 0, 0);

    ADoc1.Pages.Get_Count(APageCount1);
    ADoc2.Pages.Get_Count(APageCount2);

    ADoc1.Pages.Get_Item(0, Apage);

    bmp := TBitmap.Create;
    BuildPageBitmap(Apage, bmp, 1024);
    bmp.SaveToFile('c:\tmp\file.bmp');

    BS := FInstAUX.CreateBitSet(APageCount2);
    BS.SetSize(APageCount2);
    BS.Item[0] := True;
    BS.Item[1] := True;
    //hr := ADoc1.Pages.InsertPagesFromDocEx(ADoc2, APageCount1, BS, IPF_Annots_Copy + IPF_Bookmarks_CopyAll, nil);
    hr := ADoc1.Pages.InsertPagesFromDoc(ADoc2, 0, 1, 3, IPF_Annots_Copy or IPF_Bookmarks_CopyAll, nil);
    ADoc1.WriteToFile(PChar('c:\tmp\pagemix_1.pdf'), nil, 0);
  finally
  end;
end;

function TInst.P2X(x, dpi: double): double;
begin
  Result := (x / 72) * dpi;
end;

begin
  gInst := TInst.Create;
end.
