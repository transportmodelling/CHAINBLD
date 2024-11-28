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
  Ctl, Log,
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
    Constructor Create(const NNodes: Integer);
  end;

Constructor TLoSChainBuilder.Create(const NNodes: Integer);
begin
  inherited Create(NNodes,CtlFile.Parse('TYPES').ToStrArray);
  // Read connections
  for var Mode := 0 to NModes-1 do
  begin
    var Reader := MatrixFormats.CreateReader(CtlFile.InpProperties('IMP'+Modes[Mode]));
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
  ChainWriter: TStreamWriter;
  ChainBuilder: TLoSChainBuilder;
begin
  if ParamCount > 0 then
  begin
    var ControlFileName := ParamStr(1);
    if CtlFile.Read(ControlFileName) then
    begin
      ChainWriter := nil;
      ChainBuilder := nil;
      try
        try
          // Global settings
          SetExceptionMask( [exPrecision,exUnderflow,exDenormalized]);
          FormatSettings.DecimalSeparator := '.';
          TTextMatrixWriter.RowLabel := 'Orig';
          TTextMatrixWriter.ColumnLabel := 'Dest';
          // Open log file
          LogFile := TLogFile.Create(CtlFile.ToFileName('LOG'),true);
          LogFile.Log('Ctl-file',ExpandFileName(ControlFileName));
          LogFile.Log;
          // Create chains
          var NNodes := CtlFile.ToInt('NNODES');
          ChainWriter := TStreamWriter.Create(CtlFile.ToPath('CHAINS'));
          ChainBuilder := TLoSChainBuilder.Create(NNodes);
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
        except
          on E: Exception do
          begin
            ExitCode := 1;
            if LogFile <> nil then
            begin
              LogFile.Log;
              Logfile.Log(E)
            end else
              writeln('ERROR: ' + E.Message);
          end;
        end;
      finally
        ChainWriter.Free;
        ChainBuilder.Free;
        LogFile.Free;
      end;
    end
  end else
    writeln('Usage: ',ExtractFileName(ParamStr(0)),' "<control-file-name>"');
end.
