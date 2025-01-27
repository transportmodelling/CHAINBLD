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
  SysUtils, Math, ArrayHlp;

Type
  TConnection = Class
  public
    Function Impedance: Float64; virtual; abstract;
  end;

  TChain<ConnectionType: TConnection> = record
  // Connections must not be accessed after destroying the ChainBuilder-object
  // that generated the chain!
  private
    FAvailable,FSensible: Boolean;
    FChainType: String;
    FImpedance: Float64;
    FNodes: array {node} of Integer;
    FConnections: array {Connection} of ConnectionType;
    Function GetNodes(Node: Integer): Integer; inline;
    Function GetConnections(Connection: Integer): ConnectionType; inline;
  public
    Function NNodes: Integer; inline;
    Function NConnections: Integer; inline;
    Function Available: Boolean; inline;
    Function Sensible: Boolean; inline;
    Function Impedance: Float64; inline;
  public
    Property ChainType: String read FChainType;
    Property Nodes[Node: Integer]: Integer read GetNodes;
    Property Connections[Connection: Integer]: ConnectionType read GetConnections;
  end;

  TChainBuilder<ConnectionType: TConnection> = Class
  private
    Type
      TChainTypeRec = record
        ChainType: String;
        SubChain: Integer;
        LastMode: Integer;
        FromNodes: TArray<Integer>;
        Connections: TArray<ConnectionType>;
        Impedances: TArray<Float64>;
      end;
    Var
      FNModes,FNNodes,FNChainTypes,FOrigin: Integer;
      FModes: array of Char;
      FChainTypes: array of TChainTypeRec;
      ChainTypeIndices: array of Integer;
      // Fields used by the GetChains-method to determine whether or not a chain is sensible.
      // A Node has been visited if Visited[Node] = VisitCount
      VisitCount: UInt32;
      Visited: array {node} of UInt32;
    Function GetModes(Mode: Integer): Char; inline;
    Function GetChainTypes(ChainType: Integer): String; inline;
    Function AddMode(const Mode: Char): Integer;
    Function AddChainType(const ChainType: String): Integer;
  strict protected
    Connections: array {mode} of array {from node} of array {to node} of ConnectionType;
    Function ModeIndex(const Mode: Char): Integer;
    Function ValidChainType(const ChainType: String): Boolean; virtual;
    Function TransferPenalty(const Node,FromMode,ToMode: Integer): Float64; virtual; abstract;
  strict protected
    Property NModes: Integer read FNModes;
    Property Modes[Mode: Integer]: Char read GetModes;
  public
    Constructor Create(const NNodes: Integer; const ChainTypes: array of String); overload;
    Constructor Create(const NNodes: Integer; const ChainTypes: array of ANSIString); overload;
    Procedure BuildChains(const Origin: Integer);
    Procedure GetChain(ChainType,Destination: Integer; var Chain: TChain<ConnectionType>);
    Destructor Destroy; override;
  public
    Property NNodes: Integer read FNNodes;
    Property NChainTypes: Integer read FNChainTypes;
    Property Origin: Integer read FOrigin;
    Property ChainTypes[ChainType: Integer]: String read GetChainTypes;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TChain<ConnectionType>.GetNodes(Node: Integer): Integer;
begin
  Result := FNodes[Node];
end;

Function TChain<ConnectionType>.GetConnections(Connection: Integer): ConnectionType;
begin
  Result := FConnections[Connection];
end;

Function TChain<ConnectionType>.NNodes: Integer;
begin
  Result := Length(FNodes);
end;

Function TChain<ConnectionType>.NConnections: Integer;
begin
  Result := Length(FConnections);
end;

Function TChain<ConnectionType>.Available: Boolean;
begin
  if Length(FNodes) > 0 then
    Result := FAvailable
  else
    Result := false;
end;

Function TChain<ConnectionType>.Sensible: Boolean;
begin
  if Length(FNodes) > 0 then
    Result := FAvailable and FSensible
  else
    Result := false;
end;

Function TChain<ConnectionType>.Impedance: Float64;
begin
  if Length(FNodes) > 0 then
    Result := FImpedance
  else
    Result := Infinity;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TChainBuilder<ConnectionType>.Create(const NNodes: Integer; const ChainTypes: array of String);
begin
  inherited Create;
  FNNodes := NNodes;
  FNChainTypes := Length(ChainTypes);
  FOrigin := -1;
  SetLength(Visited,NNodes);
  SetLength(ChainTypeIndices,FNChainTypes);
  for var ChainType := 0 to FNChainTypes-1 do
  if ValidChainType(ChainTypes[ChainType]) then
    ChainTypeIndices[ChainType] := AddChainType(ChainTypes[ChainType])
  else
    ChainTypeIndices[ChainType] := -1;
  SetLength(Connections,NModes,NNodes,NNodes);
end;

Constructor TChainBuilder<ConnectionType>.Create(const NNodes: Integer; const ChainTypes: array of ANSIString);
begin
  inherited Create;
  FNNodes := NNodes;
  FNChainTypes := Length(ChainTypes);
  FOrigin := -1;
  SetLength(Visited,NNodes);
  SetLength(ChainTypeIndices,FNChainTypes);
  for var ChainType := 0 to FNChainTypes-1 do
  if ValidChainType(ChainTypes[ChainType]) then
    ChainTypeIndices[ChainType] := AddChainType(ChainTypes[ChainType])
  else
    ChainTypeIndices[ChainType] := -1;
  SetLength(Connections,NModes,NNodes,NNodes);
end;

Function TChainBuilder<ConnectionType>.GetModes(Mode: Integer): Char;
begin
  Result := FModes[Mode];
end;

Function TChainBuilder<ConnectionType>.GetChainTypes(ChainType: Integer): String;
begin
  var ChainTypeIndex := ChainTypeIndices[ChainType];
  Result := FChainTypes[ChainTypeIndex].ChainType;
end;

Procedure TChainBuilder<ConnectionType>.GetChain(ChainType,Destination: Integer; var Chain: TChain<ConnectionType>);
begin
  var ChainTypeIndex := ChainTypeIndices[ChainType];
  if ChainTypeIndex >= 0 then
  begin
    var NConnections := FChainTypes[ChainTypeIndex].ChainType.Length;
    Chain.FChainType := FChainTypes[ChainTypeIndex].ChainType;
    if (FOrigin <> Destination) or (NConnections = 1) then
    begin
      Chain.FImpedance := FChainTypes[ChainTypeIndex].Impedances[Destination];
      if Chain.FImpedance < Infinity then
      begin
        // Flag destination as visited
        if VisitCount = high(UInt32) then
        begin
          VisitCount := 1;
          for var Node := 0 to FNNodes do Visited[Node] := 0;
        end else
          Inc(VisitCount);
        Visited[Destination] := VisitCount;
        // Set results
        Chain.FAvailable := true;
        Chain.FSensible := true;
        SetLength(Chain.FNodes,NConnections+1);
        SetLength(Chain.FConnections,NConnections);
        Chain.FNodes[NConnections] := Destination;
        for var Connection := NConnections-1 downto 0 do
        begin
          Chain.FConnections[Connection] := FChainTypes[ChainTypeIndex].Connections[Destination];
          Destination := FChainTypes[ChainTypeIndex].FromNodes[Destination];
          ChainTypeIndex := FChainTypes[ChainTypeIndex].SubChain;
          Chain.FNodes[Connection] := Destination;
          if Visited[Destination] = VisitCount then
          Chain.FSensible := (FOrigin = Destination) and (NConnections = 1);
          Visited[Destination] := VisitCount;
        end;
      end else
        Chain.FAvailable := false;
    end else
      Chain.FAvailable := false;
  end else
    Chain.FAvailable := false;
end;

Function TChainBuilder<ConnectionType>.AddMode(const Mode: Char): Integer;
begin
  Result := ModeIndex(Mode);
  if Result < 0 then
  begin
    Result := FNModes;
    Inc(FNModes);
    FModes := FModes + [Mode];
  end;
end;

Function TChainBuilder<ConnectionType>.AddChainType(const ChainType: String): Integer;
Var
  SubChain: Integer;
begin
  Result := -1;
  if ChainType.Length > 0 then
  begin
    // Check for existing chain type
    for var Typ := low(FChainTypes) to high(FChainTypes) do
    if FChainTypes[Typ].ChainType = ChainType then Exit(Typ);
    // Append new chain type
    if ChainType.Length = 1 then
      SubChain := -1
    else
      begin
        var SubChainType := Copy(ChainType,1,ChainType.Length-1);
        SubChain := AddChainType(SubChainType);
      end;
    // Add chain type
    Result := Length(FChainTypes);
    SetLength(FChainTypes,Result+1);
    FChainTypes[Result].ChainType := ChainType;
    FChainTypes[Result].SubChain := SubChain;
    FChainTypes[Result].LastMode := AddMode(ChainType[ChainType.Length]);
    SetLength(FChainTypes[Result].FromNodes,FNNodes);
    SetLength(FChainTypes[Result].Connections,FNNodes);
    SetLength(FChainTypes[Result].Impedances,NNodes);
  end;
end;

Function TChainBuilder<ConnectionType>.ModeIndex(const Mode: Char): Integer;
begin
  Result := -1;
  for var Index := 0 to FNModes-1 do
  if FModes[Index] = Mode then Exit(Index);
end;

Function TChainBuilder<ConnectionType>.ValidChainType(const ChainType: String): Boolean;
begin
  Result := true;
end;

Procedure TChainBuilder<ConnectionType>.BuildChains(const Origin: Integer);
begin
  FOrigin := Origin;
  for var ChainType := low(FChainTypes) to high(FChainTypes) do
  begin
    var Mode := FChainTypes[ChainType].LastMode;
    var ChainTypeImpedances := FChainTypes[ChainType].Impedances;
    var ChainTypeConnections := FChainTypes[ChainType].Connections;
    var FromNodes := FChainTypes[ChainType].FromNodes;
    if FChainTypes[ChainType].ChainType.Length = 1 then
    begin
      for var ToNode := 0 to FNNodes-1 do
      if Connections[Mode,Origin,ToNode] <> nil then
      begin
        FromNodes[ToNode] := Origin;
        ChainTypeConnections[ToNode] := Connections[Mode,Origin,ToNode];
        ChainTypeImpedances[ToNode] := ChainTypeConnections[ToNode].Impedance;
      end else
        ChainTypeImpedances[ToNode] := Infinity;
    end else
    begin
      var SubChain := FChainTypes[ChainType].SubChain;
      var SubChainMode := FChainTypes[SubChain].LastMode;
      var FromNodeImpedances := FChainTypes[SubChain].Impedances;
      ChainTypeImpedances.Initialize(Infinity);
      for var FromNode := 0 to FNNodes-1 do
      begin
        var FromNodeImpedance := FromNodeImpedances[FromNode];
        if FromNodeImpedance < Infinity then
        begin
          for var ToNode := 0 to FNNodes-1 do
          if Connections[Mode,FromNode,ToNode] <> nil then
          begin
            var Imp := FromNodeImpedance +
                       TransferPenalty(FromNode,SubChainMode,Mode) +
                       Connections[Mode,FromNode,ToNode].Impedance;
            if Imp < ChainTypeImpedances[ToNode] then
            begin
              FromNodes[ToNode] := FromNode;
              ChainTypeConnections[ToNode] := Connections[Mode,FromNode,ToNode];
              ChainTypeImpedances[ToNode] := Imp;
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
