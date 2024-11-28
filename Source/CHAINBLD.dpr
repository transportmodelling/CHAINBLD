program CHAINBLD;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/CHAINBLD
//
////////////////////////////////////////////////////////////////////////////////

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Classes,
  SysUtils,
  IOUtils,
  Math,
  PropSet,
  Parse,
  ArrayHlp,
  matio, matio.Formats, matio.Text,
  Chain in 'Chain.pas';

Type
  TSkimVar = Class(TConnection)
  private
    FSkimVar: Float64;
  public
    Constructor Create(SkimVar: Float64);
    Function Impedance: Float64; override;
  end;

Constructor TSkimVar.Create(SkimVar: Float64);
begin
  inherited Create;
  FSkimvar := Skimvar;
end;

Function TSkimVar.Impedance: Float64;
begin
  Result := FSkimVar;
end;

////////////////////////////////////////////////////////////////////////////////

Type
  TLoSChainBuilder = Class(TChainBuilder<TSkimVar>)
  private
    Const
      InfProxy = 0.0;
  strict protected
    Function TransferPenalty(const Node,FromMode,ToMode: Integer): Float64; override;
  public
    Constructor Create(const NNodes: Integer; const [ref] ControlFile: TPropertySet);
  end;

Constructor TLoSChainBuilder.Create(const NNodes: Integer; const [ref] ControlFile: TPropertySet);
begin
  inherited Create(NNodes,ControlFile.Parse('TYPES').ToStrArray);
  // Read connections
  for var Mode := 0 to NModes-1 do
  begin
    var Reader := MatrixFormats.CreateReader(ControlFile['IMP'+Modes[Mode]]);
    try
      var Impedances := TMatrixRow.Create(NNodes);
      for var FromNode := 0 to NNodes-1 do
      begin
        Reader.Read([Impedances]);
        for var ToNode := 0 to NNodes-1 do
        if Impedances[ToNode] <> InfProxy then
        Connections[Mode,FromNode,ToNode] := TSkimVar.Create(Impedances[ToNode])
      end;
    finally
      Reader.Free;
    end;
  end;
end;

Function TLoSChainBuilder.TransferPenalty(const Node,FromMode,ToMode: Integer): Float64;
begin
  Result := 0.0;
end;

////////////////////////////////////////////////////////////////////////////////

Var
  ControlFile: TPropertySet;
  ChainWriter: TStreamWriter;
  ChainBuilder: TLoSChainBuilder;
begin
  if ParamCount > 0 then
  begin
    var ControlFileName := ExpandFileName(ParamStr(1));
    if FileExists(ControlFileName) then
    begin
      var BaseDir := IncludeTrailingPathDelimiter(ExtractFileDir(ControlFileName));
      FormatSettings.DecimalSeparator := '.';
      // All relative paths are supposed to be relative to the control file path!
      TPropertySet.BaseDirectory := BaseDir;
      TTextMatrixWriter.RowLabel := 'Orig';
      TTextMatrixWriter.ColumnLabel := 'Dest';
      try
        // Read control file
        ControlFile.NameValueSeparator := ':';
        ControlFile.PropertiesSeparator := ';';
        ControlFile.AsStrings := TFile.ReadAllLines(ControlFileName);
        // Create chains
        var NNodes := ControlFile.ToInt('NNODES');
        ChainWriter := nil;
        ChainBuilder := nil;
        try
          ChainWriter := TStreamWriter.Create(ControlFile.ToPath('CHAINS'));
          ChainBuilder := TLoSChainBuilder.Create(NNodes,ControlFile);
          for var Origin := 0 to NNodes-1 do
          begin
            ChainBuilder.BuildChains(Origin);
            for var Destination := 0 to NNodes-1 do
            for var ChainType := 0 to ChainBuilder.NChainTypes-1 do
            begin
              var Chain := ChainBuilder[ChainType,Destination];
              if Chain.Sensible then
              begin
                ChainWriter.Write(Origin+1);
                ChainWriter.Write(#9);
                ChainWriter.Write(Destination+1);
                ChainWriter.Write(#9);
                ChainWriter.Write(ChainBuilder.ChainTypes[ChainType]);
                ChainWriter.Write(#9);
                ChainWriter.Write(FormatFloat('0.###',Chain.Impedance));
                for var Node := 0 to Chain.NNodes-1 do
                begin
                  ChainWriter.Write(#9);
                  ChainWriter.Write(Chain.Nodes[Node]+1);
                end;
                ChainWriter.WriteLine;
              end;
            end;
          end;
        finally
          ChainBuilder.Free;
          ChainWriter.Free;
        end;
      except
        on E: Exception do
        begin
          ExitCode := 1;
          writeln('ERROR: ' + E.Message);
        end;
      end;
    end else
      writeln('Control file does not exist');
  end else
    writeln('Usage CHAINBLD <control file>');
end.
