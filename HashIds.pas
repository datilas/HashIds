unit HashIds;

interface

const
  cminAlphabetLength = 16;
  cAlphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890';
  cSeps = 'cfhistuCFHISTU';
  cguardDiv = 12;

type

  TIDs = array of Integer;

  { THashIds }

  THashIds = class(TObject)
  private
    FAlphabet: string;
    FSalt: string;
    FMinHashLength: Integer;
    FSeparators: string;
    FGuards: string;
    function Hash(const Input: Integer; const HashStr: string): string;
    function Unhash(const Input, HashStr: string): Integer;
    function ConsistentShuffle(const Value, Shuffle: string): string;
    function Encode(Numbers: TIDs): string;
    function Decode(const aHash: string): TIDs;
  public
    function Encrypt(Id: Integer): string; overload;
    function Encrypt(CommaSeperatedIds: string): string; overload;
    function Encrypt(Numbers: TIDs): string; overload;
    function Decrypt(Value: string): TIDs;
    function DecryptToStr(Value: string): string;
    constructor Create(Salt: string = ''; MinHashLength: Integer = 0; Alphabet: string = '');
    destructor Destroy; override;
  end;

implementation

uses Classes, SysUtils, Math;

Constructor THashIds.Create(Salt: string; MinHashLength: Integer; Alphabet: string);
var
  s: string;
  n: Integer;
begin
  inherited Create;
  if Length(Salt) = 0 then
    Self.FSalt := ''
  else
    Self.FSalt := Salt;

  Self.FMinHashLength := MinHashLength;

  if Length(Alphabet) = 0 then
    Self.FAlphabet := cAlphabet
  else
    Self.FAlphabet := Alphabet;

  Self.FSeparators := cSeps;

  // Remove duplicate characters from alphabet
  s := '';
  for n := 1 to Length(Self.FAlphabet) do
  Begin
    if pos(Self.FAlphabet[n], s) = 0 then
      s := s + Self.FAlphabet[n];
  End;

  Self.FAlphabet := s;

  if pos(' ', Self.FAlphabet) > 0 then
    raise Exception.Create('error: alphabet cannot contain spaces');

  if Length(Self.FAlphabet) < cminAlphabetLength then
    raise Exception.Create('"error: alphabet must contain at least ' + IntToStr(cminAlphabetLength) + ' unique characters');

  // Separators should NOT contain only characters present in alphabet
  s := '';
  for n := 1 to Length(Self.FSeparators) do
  Begin
    if pos(Self.FSeparators[n], Self.FAlphabet) > 0 then
      s := s + Self.FSeparators[n];
  End;

  Self.FSeparators := s;

  // alphabet should contain NOT characters present in Separators
  s := '';
  for n := 1 to Length(Self.FAlphabet) do
  Begin
    if pos(Self.FAlphabet[n], Self.FSeparators) = 0 then
      s := s + Self.FAlphabet[n];
  End;

  Self.FAlphabet := s;
  // Shuffel Separators
  Self.FSeparators := ConsistentShuffle(Self.FSeparators, Self.FSalt);
  // Shuffel Alphabet

  Self.FAlphabet := ConsistentShuffle(Self.FAlphabet, Self.FSalt);
  n := Round(Length(Self.FAlphabet) / cguardDiv);

  if Length(Self.FAlphabet) < 3 then
  begin
    Self.FGuards := Copy(Self.FSeparators, 1, n);
    Self.FSeparators := Copy(Self.FSeparators, n + 1);
  end
  else
  begin
    Self.FGuards := Copy(Self.FAlphabet, 1, n);
    Self.FAlphabet := Copy(Self.FAlphabet, n + 1);
  end;
end;

Destructor THashIds.Destroy;
begin
  inherited Destroy;
end;

Function THashIds.Encrypt(CommaSeperatedIds: string): string;
var
  nums: TIDs;
  list: TStringList;
  n: Integer;
begin
  list := TStringList.Create;
  try
    list.CommaText := CommaSeperatedIds;
    if list.Count = 0 then Exit;
    SetLength(nums, list.Count);

    for n := 0 to list.Count - 1 do
    begin
      try
        nums[n] := StrToInt(list[n])
      except
        on E: Exception do
        begin
          raise Exception.Create('Error where convering string "' + list[n] + '" to a number: ' + E.Message);
        end;
      end;

      if nums[n] < 0 then
        raise Exception.Create('Id must be greather or equal to zero');
    end;
  finally
    list.Free;
  end;
  Result := Encode(nums);
end;

Function THashIds.Encrypt(Id: Integer): string;
var
  num: TIDs;
begin
  Result := '';
  SetLength(num, 1);
  num[Low(num)] := Id;
  Result := Encode(num);
end;

Function THashIds.Encrypt(Numbers: TIDs): string;
begin
  Result := Encode(Numbers);
end;

Function THashIds.Decrypt(Value: string): TIDs;
begin
  SetLength(Result, 0);
  if Value = '' then Exit;
  Result := Decode(Value);
end;

Function THashIds.DecryptToStr(Value: string): string;
var
  Ids: TIDs;
  n: Integer;
begin
  Result := '';
  Ids := Decrypt(Value);
  for n := Low(Ids) to High(Ids) do
  begin
    if n > 0 then Result := Result + ',';
    Result := Result + IntToStr(Ids[n]);
  end;
end;

Function THashIds.Encode(Numbers: TIDs): string;
var
  n: Integer;
  numbersHashInt: Integer;
  sAlphabet: string;
  sLottery: string;
  Last: string;
begin
  sAlphabet := Self.FAlphabet;
  numbersHashInt := 0;

  for n := Low(Numbers) to High(Numbers) do
    numbersHashInt := numbersHashInt + (Numbers[n] mod (n + 100));

  sLottery := sAlphabet[(numbersHashInt mod Length(sAlphabet)) + 1]; // Delphi string start at 1 not at 0
  Result := sLottery;

  for n := Low(Numbers) to High(Numbers) do
  begin
    sAlphabet := ConsistentShuffle(sAlphabet, sLottery + Self.FSalt + sAlphabet);
    Last := Hash(Numbers[n], sAlphabet);
    Result := Result + Last;

    if (n < High(Numbers)) then
      Result := Result + Self.FSeparators[((Numbers[n] mod (Ord(Last[1]) + n)) mod Length(Self.FSeparators)) + 1];
  end;

  if Length(Result) < Self.FMinHashLength then
  begin
    Result := Self.FGuards[((numbersHashInt + Ord(Result[1])) mod Length(Self.FGuards)) + 1] + Result;

    if Length(Result) < Self.FMinHashLength then
      Result := Result + Self.FGuards[((numbersHashInt + Ord(Result[3])) mod Length(Self.FGuards)) + 1];

    n := Length(sAlphabet) div 2;
    while (Length(Result) < Self.FMinHashLength) do
    begin
      sAlphabet := ConsistentShuffle(sAlphabet, sAlphabet);
      Result := Copy(sAlphabet, n + 1) + Result + Copy(sAlphabet, 1, n);

      if Length(Result) > Self.FMinHashLength then
      begin
        Result := Copy(Result, ((Length(Result) - Self.FMinHashLength) div 2) + 1, Self.FMinHashLength);
      end;
    end;
  end;
end;

Function THashIds.Decode(Const aHash: string): TIDs;
var
  sAlphabet: string;
  sLottery: string;
  n: Integer;
  HashList: TStringList;
  s: string;
begin
  SetLength(Result, 0);
  s := aHash;
  for n := 1 to Length(Self.FGuards) do
    s := StringReplace(s, Self.FGuards[n], ',', [rfReplaceAll]);

  sAlphabet := Self.FAlphabet;
  HashList := TStringList.Create;
  try
    HashList.CommaText := s;
    if HashList.Count > 1 then
      s := HashList[1]
    else
      s := aHash;

    HashList.Clear;
    for n := 1 to Length(Self.FSeparators) do
      s := StringReplace(s, Self.FSeparators[n], ',', [rfReplaceAll]);

    HashList.CommaText := s;

    if HashList.Count = 0 then Exit;

    sLottery := HashList[0][1];
    HashList[0] := Copy(HashList[0], 2);
    SetLength(Result, HashList.Count);

    for n := 0 to HashList.Count - 1 do
    begin
      sAlphabet := ConsistentShuffle(sAlphabet, sLottery + Self.FSalt + sAlphabet);
      Result[n] := Unhash(HashList[n], sAlphabet);
    end;

    if Encode(Result) <> aHash then
      SetLength(Result, 0);
  finally
    HashList.Free;
  end;
end;

Function THashIds.Hash(Const Input: Integer; Const HashStr: string): string;
var
  n: Integer;
  alphabetLength: Integer;
begin
  Result := '';
  n := Input;
  alphabetLength := Length(HashStr);
  repeat
    Result := HashStr[(n mod alphabetLength) + 1] + Result;
    n := n div alphabetLength;
  until n = 0;
end;

Function THashIds.Unhash(Const Input, HashStr: string): Integer;
var
  n: Integer;
begin
  Result := 0;
  for n := 1 to Length(Input) do
    Result := Result + (pos(Input[n], HashStr) - 1) * Round(Power(Length(HashStr), Length(Input) - n));
end;

Function THashIds.ConsistentShuffle(Const Value, Shuffle: string): string;
var
  i, v, p, j, n: Integer;
  k: Char;
begin
  Result := Value;
  if Length(Shuffle) = 0 then Exit;
  i := Length(Value) - 1;
  v := 0;
  p := 0;

  while i > 0 do
  begin
    v := v mod Length(Shuffle);
    n := Ord(Shuffle[v + 1]);
    p := p + n;
    j := (n + v + p) mod i;
    k := Result[j + 1];
    Result := Copy(Result, 1, j) + Result[i + 1] + Copy(Result, j + 2);
    Result := Copy(Result, 1, i) + k + Copy(Result, i + 2);
    Dec(i);
    Inc(v);
  end;
end;

end.
