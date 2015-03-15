unit DebugTools;

interface

uses
  Windows, Classes, SysUtils;

procedure SetDebugStr(AMsg:string);
function GetDebugStr:string;

procedure Trace(const AMsg:string);

implementation

var
  DebugStr : string = '';  // TODO: ������ �������ϵ��� ����

procedure SetDebugStr(AMsg:string);
begin
  DebugStr := AMsg;
end;

function GetDebugStr:string;
begin
  Result := DebugStr;
end;

procedure Trace(const AMsg:string);
begin
  // DebugView���� ���͸��ϱ� ���ؼ� �ױ׸� �ٿ� ��
  OutputDebugString(PChar('[MW] ' + AMsg));
end;

end.
