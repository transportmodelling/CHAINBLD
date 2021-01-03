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
  matio,matio.Formats,matio.Text,
  Chain in 'Chain.pas';

Type
  TLoSTChainBuilder = Class(TChainBuilder)
  private
    Const
      InfProxy = 0.0;
    Var
      Impedances: array {mode} of array {from node} of TFloat64MatrixRow;
  strict protected
    Function Impedance(const FromNode,ToNode,Mode: Integer): Float64; override;
    Function TransferPenalty(const Node,FromMode,ToMode: Integer): Float64; override;
  public
    Constructor Create(const NNodes: Integer; const [ref] ControlFile: TPropertySet);
  end;

Constructor TLoSTChainBuilder.Create(const NNodes: Integer; const [ref] ControlFile: TPropertySet);
begin
  inherited Create(NNodes,ControlFile.Parse('TYPES').ToStrArray);
  // Read impedances
  SetLength(Impedances,Length(Modes),NNodes);
  for var Mode := low(Modes) to high(Modes) do
  begin
    var Reader := MatrixFormats.CreateReader(ControlFile['IMP'+Modes[Mode]]);
    try
      for var FromNode := 0 to NNodes-1 do
      begin
        Impedances[Mode,FromNode].Length := NNodes;
        Reader.Read([Impedances[Mode,FromNode]])
      end;
    finally
      Reader.Free;
    end;
  end;
end;

Function TLoSTChainBuilder.Impedance(const FromNode,ToNode,Mode: Integer): Float64;
begin
  Result := Impedances[Mode,FromNode,ToNode];
  if Result = InfProxy then Result := Infinity;
end;

Function TLoSTChainBuilder.TransferPenalty(const Node,FromMode,ToMode: Integer): Float64;
begin
  Result := 0.0;
end;

////////////////////////////////////////////////////////////////////////////////

Var
  ControlFile: TPropertySet;
  ChainWriter: TStreamWriter;
  ChainBuilder: TLoSTChainBuilder;
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
          ChainBuilder := TLoSTChainBuilder.Create(NNodes,ControlFile);
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
                for var Leg := 0 to Chain.NLegs do
                begin
                  ChainWriter.Write(#9);
                  ChainWriter.Write(Chain.Nodes[Leg]+1);
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
