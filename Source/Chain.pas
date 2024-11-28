unit Chain;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/CHAINBLD
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  Math, ArrayHlp;

Type
  TChainType = Type String;

  TChainTypeHelper = record helper for TChainType
  private
    Function NConnections: Integer;
    Function SubChain: TChainType;
    Function LastMode: Char;
  end;

  TConnection = Class
  public
    Function Impedance: Float64; virtual; abstract;
  end;

  TChain<ConnectionType: TConnection> = record
  private
    FAvailable: Boolean;
    FChainType: TChainType;
    FNNodes,FNConnections: Integer;
    FImpedance: Float64;
    FNodes: array {node} of Integer;
    FConnections: array {Connection} of ConnectionType;
    Function GetNodes(Node: Integer): Integer; inline;
    Function GetConnections(Connection: Integer): ConnectionType; inline;
  public
    Function Sensible: Boolean;
  public
    Property Available: Boolean read FAvailable;
    Property ChainType: TChainType read FChainType;
    Property NNodes: Integer read FNNodes;
    Property NConnections: Integer read FNConnections;
    Property Impedance: Float64 read FImpedance;
    Property Nodes[Node: Integer]: Integer read GetNodes;
    Property Connections[Connection: Integer]: ConnectionType read GetConnections;
  end;

  TChainBuilder<ConnectionType: TConnection> = Class
  private
    Type
      TChainTypeRec = record
        ChainType: TChainType;
        SubChain: Integer;
        LastMode: Integer;
        FromNodes: TArray<Integer>;
        Connections: TArray<ConnectionType>;
        Impedances: TArray<Float64>;
      end;
    Var
      FNModes,FNNodes,FNChainTypes: Integer;
      FModes: array of Char;
      FChainTypes: array of TChainTypeRec;
      ChainTypeIndices: array of Integer;
    Function GetModes(Mode: Integer): Char; inline;
    Function GetChainTypes(ChainType: Integer): TChainType; inline;
    Function GetChains(ChainType,Destination: Integer): TChain<ConnectionType>;
    Function AddMode(const Mode: Char): Integer;
    Function AddChainType(const ChainType: TChainType): Integer;
  strict protected
    Connections: array {mode} of array {from node} of array {to node} of ConnectionType;
    Function TransferPenalty(const Node,FromMode,ToMode: Integer): Float64; virtual; abstract;
  strict protected
    Property NModes: Integer read FNModes;
    Property Modes[Mode: Integer]: Char read GetModes;
  public
    Constructor Create(const NNodes: Integer; const ChainTypes: array of String);
    Procedure BuildChains(const Origin: Integer);
    Destructor Destroy; override;
  public
    Property NNodes: Integer read FNNodes;
    Property NChainTypes: Integer read FNChainTypes;
    Property ChainTypes[ChainType: Integer]: TChainType read GetChainTypes;
    Property Chains[ChainType,Destination: Integer]: TChain<ConnectionType> read GetChains; default;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TChainTypeHelper.NConnections: Integer;
begin
  Result := Length(Self);
end;

Function TChainTypeHelper.SubChain: TChainType;
begin
  if NConnections = 1 then
    Result := ''
  else
    Result := Copy(Self,1,NConnections-1);
end;

Function TChainTypeHelper.LastMode: Char;
begin
  Result := Self[NConnections];
end;

////////////////////////////////////////////////////////////////////////////////

Function TChain<ConnectionType>.GetNodes(Node: Integer): Integer;
begin
  Result := FNodes[Node];
end;

Function TChain<ConnectionType>.GetConnections(Connection: Integer): ConnectionType;
begin
  Result := FConnections[Connection];
end;

Function TChain<ConnectionType>.Sensible: Boolean;
begin
  if FAvailable then
  begin
    // Check whether all nodes occur only once, except for intrazonal
    Result := true;
    for var CheckNode := 0 to FNNodes-2 do
    begin
      var Check := FNodes[CheckNode];
      for var Node := CheckNode+1 to NNodes-1 do
      if FNodes[Node] = Check then
      if (CheckNode > 0) or (Node < NNodes-1) then Exit(false);
    end;
  end else
    Result := false;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TChainBuilder<ConnectionType>.Create(const NNodes: Integer; const ChainTypes: array of String);
begin
  inherited Create;
  FNNodes := NNodes;
  FNChainTypes := Length(ChainTypes);
  SetLength(ChainTypeIndices,FNChainTypes);
  for var ChainType := 0 to FNChainTypes-1 do
  ChainTypeIndices[ChainType] := AddChainType(ChainTypes[ChainType]);
  SetLength(Connections,NModes,NNodes,NNodes);
end;

Function TChainBuilder<ConnectionType>.GetModes(Mode: Integer): Char;
begin
  Result := FModes[Mode];
end;

Function TChainBuilder<ConnectionType>.GetChainTypes(ChainType: Integer): TChainType;
begin
  var ChainTypeIndex := ChainTypeIndices[ChainType];
  Result := FChainTypes[ChainTypeIndex].ChainType;
end;

Function TChainBuilder<ConnectionType>.GetChains(ChainType,Destination: Integer): TChain<ConnectionType>;
begin
  var ChainTypeIndex := ChainTypeIndices[ChainType];
  var NConnections := FChainTypes[ChainTypeIndex].ChainType.NConnections;
  Result.FChainType := FChainTypes[ChainTypeIndex].ChainType;
  Result.FNNodes := NConnections+1;
  Result.FNConnections := NConnections;
  Result.FImpedance := FChainTypes[ChainTypeIndex].Impedances[Destination];
  if FChainTypes[ChainTypeIndex].Impedances[Destination] < Infinity then
  begin
    Result.FAvailable := true;
    SetLength(Result.FNodes,NConnections+1);
    SetLength(Result.FConnections,NConnections);
    Result.FNodes[NConnections] := Destination;
    for var Connection := NConnections-1 downto 0 do
    begin
      Result.FConnections[Connection] := FChainTypes[ChainTypeIndex].Connections[Destination];
      Destination := FChainTypes[ChainTypeIndex].FromNodes[Destination];
      ChainTypeIndex := FChainTypes[ChainTypeIndex].SubChain;
      Result.FNodes[Connection] := Destination;
    end;
  end else
    Result.FAvailable := false;
end;

Function TChainBuilder<ConnectionType>.AddMode(const Mode: Char): Integer;
begin
  // Check for existing mode
  for var ModeIndex := 0 to FNModes-1 do
  if FModes[ModeIndex] = Mode then Exit(ModeIndex);
  // Append new mode
  Result := FNModes;
  Inc(FNModes);
  FModes := FModes + [Mode];
end;

Function TChainBuilder<ConnectionType>.AddChainType(const ChainType: TChainType): Integer;
Var
  SubChain: Integer;
begin
  Result := -1;
  if ChainType.NConnections > 0 then
  begin
    // Check for existing chain type
    for var Typ := low(FChainTypes) to high(FChainTypes) do
    if FChainTypes[Typ].ChainType = ChainType then Exit(Typ);
    // Append new chain type
    if ChainType.NConnections = 1 then
      SubChain := -1
    else
      SubChain := AddChainType(ChainType.SubChain);
    // Add chain type
    Result := Length(FChainTypes);
    SetLength(FChainTypes,Result+1);
    FChainTypes[Result].ChainType := ChainType;
    FChainTypes[Result].SubChain := SubChain;
    FChainTypes[Result].LastMode := AddMode(ChainType.LastMode);
    SetLength(FChainTypes[Result].FromNodes,FNNodes);
    SetLength(FChainTypes[Result].Connections,FNNodes);
    SetLength(FChainTypes[Result].Impedances,NNodes);
  end;
end;

Procedure TChainBuilder<ConnectionType>.BuildChains(const Origin: Integer);
begin
  for var ChainType := low(FChainTypes) to high(FChainTypes) do
  begin
    var Mode := FChainTypes[ChainType].LastMode;
    var Impedances := FChainTypes[ChainType].Impedances;
    var Connections := FChainTypes[ChainType].Connections;
    var FromNodes := FChainTypes[ChainType].FromNodes;
    if FChainTypes[ChainType].ChainType.NConnections = 1 then
    begin
      for var ToNode := 0 to FNNodes-1 do
      if Self.Connections[Mode,Origin,ToNode] <> nil then
      begin
        FromNodes[ToNode] := Origin;
        Connections[ToNode] := Self.Connections[Mode,Origin,ToNode];
        Impedances[ToNode] := Connections[ToNode].Impedance;
      end else
        Impedances[ToNode] := Infinity;
    end else
    begin
      var SubChain := FChainTypes[ChainType].SubChain;
      var SubChainMode := FChainTypes[SubChain].LastMode;
      var FromNodeImpedances := FChainTypes[SubChain].Impedances;
      Impedances.Initialize(Infinity);
      for var FromNode := 0 to FNNodes-1 do
      begin
        var FromNodeImpedance := FromNodeImpedances[FromNode];
        if FromNodeImpedance < Infinity then
        begin
          for var ToNode := 0 to FNNodes-1 do
          if Self.Connections[Mode,FromNode,ToNode] <> nil then
          begin
            var Imp := FromNodeImpedance +
                       TransferPenalty(FromNode,SubChainMode,Mode) +
                       Self.Connections[Mode,FromNode,ToNode].Impedance;
            if Imp < Impedances[ToNode] then
            begin
              FromNodes[ToNode] := FromNode;
              Connections[ToNode] := Self.Connections[Mode,FromNode,ToNode];
              Impedances[ToNode] := Imp;
            end;
          end;
        end;
      end;
    end;
  end;
end;

Destructor TChainBuilder<ConnectionType>.Destroy;
begin
  for var Mode := 0 to NModes-1 do
  for var FromNode := 0 to NNodes-1 do
  for var ToNode := 0 to NNodes-1 do
  Connections[Mode,FromNode,ToNode].Free;
  inherited Destroy;
end;

end.
