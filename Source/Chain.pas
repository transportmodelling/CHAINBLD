unit Chain;

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  Math,ArrayHlp;

Type
  TChainType = Type String;

  TChainTypeHelper = record helper for TChainType
  public
    Function NLegs: Integer;
    Function SubChain: TChainType;
    Function LastLeg: Char;
  end;

  TChain = record
  private
    FNLegs: Integer;
    FImpedance: Float64;
    FNodes: array of Integer;
    Function GetNodes(Node: Integer): Integer; inline;
  public
    Function Sensible: Boolean;
  public
    Property NLegs: Integer read FNLegs;
    Property Impedance: Float64 read FImpedance;
    Property Nodes[Node: Integer]: Integer read GetNodes; default;
  end;

  TChainBuilder = Class
  private
    Type
      TChainTypeRec = record
        ChainType: TChainType;
        SubChain: Integer;
        LastLegMode: Integer;
        FromNodes: TArray<Integer>;
        Impedances: TArray<Float64>;
      end;
    Var
      FNNodes,FNChainTypes: Integer;
      FChainTypes: array of TChainTypeRec;
      ChainTypeIndices: array of Integer;
    Function GetChainTypes(ChainType: Integer): TChainType; inline;
    Function GetChains(ChainType,Destination: Integer): TChain;
    Function AddMode(const LegMode: Char): Integer;
    Function AddChainType(const ChainType: TChainType): Integer;
  strict protected
    Modes: array of Char;
    Function Impedance(const FromNode,ToNode,Mode: Integer): Float64; virtual; abstract;
    Function TransferPenalty(const Node,FromMode,ToMode: Integer): Float64; virtual; abstract;
  public
    Constructor Create(const NNodes: Integer; const ChainTypes: array of String);
    Procedure BuildChains(const Origin: Integer);
  public
    Property NNodes: Integer read FNNodes;
    Property NChainTypes: Integer read FNChainTypes;
    Property ChainTypes[ChainType: Integer]: TChainType read GetChainTypes;
    Property Chains[ChainType,Destination: Integer]: TChain read GetChains; default;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TChainTypeHelper.NLegs: Integer;
begin
  Result := Length(Self);
end;

Function TChainTypeHelper.SubChain: TChainType;
begin
  if NLegs = 1 then
    Result := ''
  else
    Result := Copy(Self,1,NLegs-1);
end;

Function TChainTypeHelper.LastLeg: Char;
begin
  Result := Self[NLegs];
end;

////////////////////////////////////////////////////////////////////////////////

Function TChain.GetNodes(Node: Integer): Integer;
begin
  Result := FNodes[Node];
end;

Function TChain.Sensible: Boolean;
begin
  if FImpedance < Infinity then
  begin
    // Check whether all nodes only occur once
    Result := true;
    for var CheckNode := 0 to FNLegs-1 do
    begin
      var Check := FNodes[CheckNode];
      for var Node := CheckNode+1 to NLegs do
      if FNodes[Node] = Check then Exit(false);
    end;
  end else
    result := false;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TChainBuilder.Create(const NNodes: Integer; const ChainTypes: array of String);
begin
  inherited Create;
  FNNodes := NNodes;
  FNChainTypes := Length(ChainTypes);
  SetLength(ChainTypeIndices,FNChainTypes);
  for var ChainType := 0 to FNChainTypes-1 do
  ChainTypeIndices[ChainType] := AddChainType(ChainTypes[ChainType]);
end;

Function TChainBuilder.GetChainTypes(ChainType: Integer): TChainType;
begin
  var ChainTypeIndex := ChainTypeIndices[ChainType];
  Result := FChainTypes[ChainTypeIndex].ChainType;
end;

Function TChainBuilder.GetChains(ChainType,Destination: Integer): TChain;
begin
  var ChainTypeIndex := ChainTypeIndices[ChainType];
  var NLegs := FChainTypes[ChainTypeIndex].ChainType.NLegs;
  Result.FNLegs := NLegs;
  Result.FImpedance := FChainTypes[ChainTypeIndex].Impedances[Destination];
  SetLength(Result.FNodes,NLegs+1);
  Result.FNodes[NLegs] := Destination;
  for var Leg := NLegs-1 downto 0 do
  begin
    Destination := FChainTypes[ChainTypeIndex].FromNodes[Destination];
    ChainTypeIndex := FChainTypes[ChainTypeIndex].SubChain;
    Result.FNodes[Leg] := Destination;
  end;
end;

Function TChainBuilder.AddMode(const LegMode: Char): Integer;
begin
  // Check for existing mode
  for var Mode := low(Modes) to high(Modes) do
  if Modes[Mode] = LegMode then Exit(Mode);
  // Append new mode
  Result := Length(Modes);
  Modes := Modes + [LegMode];
end;

Function TChainBuilder.AddChainType(const ChainType: TChainType): Integer;
Var
  SubChain: Integer;
begin
  Result := -1;
  if ChainType.NLegs > 0 then
  begin
    // Check for existing chain type
    for var Typ := low(FChainTypes) to high(FChainTypes) do
    if FChainTypes[Typ].ChainType = ChainType then Exit(Typ);
    // Append new chain type
    if ChainType.NLegs = 1 then
      SubChain := -1
    else
      SubChain := AddChainType(ChainType.SubChain);
    // Add chain type
    Result := Length(FChainTypes);
    SetLength(FChainTypes,Result+1);
    FChainTypes[Result].ChainType := ChainType;
    FChainTypes[Result].SubChain := SubChain;
    FChainTypes[Result].LastLegMode := AddMode(ChainType.LastLeg);
    FChainTypes[Result].FromNodes.Length := FNNodes;
    FChainTypes[Result].Impedances.Length := NNodes;
  end;
end;

Procedure TChainBuilder.BuildChains(const Origin: Integer);
begin
  for var ChainType := low(FChainTypes) to high(FChainTypes) do
  begin
    var Mode := FChainTypes[ChainType].LastLegMode;
    var Impedances := FChainTypes[ChainType].Impedances;
    var FromNodes := FChainTypes[ChainType].FromNodes;
    if FChainTypes[ChainType].ChainType.NLegs = 1 then
    begin
      for var ToNode := 0 to FNNodes-1 do
      begin
        FromNodes[ToNode] := Origin;
        Impedances[ToNode] := Impedance(Origin,ToNode,Mode);
      end;
    end else
    begin
      var SubChain := FChainTypes[ChainType].SubChain;
      var SubChainMode := FChainTypes[SubChain].LastLegMode;
      var FromNodeImpedances := FChainTypes[SubChain].Impedances;
      Impedances.Initialize(Infinity);
      for var FromNode := 0 to FNNodes-1 do
      begin
        var FromNodeImpedance := FromNodeImpedances[FromNode];
        if FromNodeImpedance < Infinity then
        begin
          for var ToNode := 0 to FNNodes-1 do
          begin
            var Imp := FromNodeImpedance +
                       TransferPenalty(FromNode,SubChainMode,Mode) +
                       Impedance(FromNode,ToNode,Mode);
            if Imp < Impedances[ToNode] then
            begin
              FromNodes[ToNode] := FromNode;
              Impedances[ToNode] := Imp;
            end;
          end;
        end;
      end;
    end;
  end;
end;

end.
