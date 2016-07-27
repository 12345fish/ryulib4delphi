unit TaskQueue;

interface

uses
  RyuLibBase, SimpleThread, SuspensionQueue,
  SysUtils, Classes, SyncObjs;

type
  TTaskEnvet<TTaskType, TDataType> = procedure (ATaskType:TTaskType; ADataType:TDataType) of object;

  TItem<TTaskType, TDataType> = class
  private
    FTaksType : TTaskType;
    FDataType : TDataType;
  public
    constructor Create(ATaskType:TTaskType; ADataType:TDataType); reintroduce;
  end;

  {*
    ó���ؾ� �� �۾��� ť�� �ְ� ���ʷ� �����Ѵ�.
    �۾��� ������ ������ �����带 �̿��ؼ� �񵿱�� �����Ѵ�.
    �۾� ��û�� �پ��� �����忡�� ����Ǵµ�, �������� ������ �ʿ� �� �� ����Ѵ�.
    ��û �� �۾��� ��û�� ������� ������ �����忡�� ����Ǿ�� �� �� ����Ѵ�.  (�񵿱� ����)
  }
  TTaskQueue<TTaskType, TDataType> = class
  private
    FSuspensionQueue : TSuspensionQueue<TItem<TTaskType, TDataType>>;
  private
    FSimpleThread : TSimpleThread;
    procedure on_FSimpleThread_Execute(ASimpleThread:TSimpleThread);
  private
    FOnTask: TTaskEnvet<TTaskType, TDataType>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    procedure Add(ATaskType:TTaskType; ADataType:TDataType);
  public
    property OnTask : TTaskEnvet<TTaskType, TDataType> read FOnTask write FOnTask;
  end;

implementation

{ TItem<TTaskType, TDataType> }

constructor TItem<TTaskType, TDataType>.Create(ATaskType: TTaskType;
  ADataType: TDataType);
begin
  FTaksType := ATaskType;
  FDataType := ADataType;
end;

{ TTaskQueue<TTaskType, TDataType> }

procedure TTaskQueue<TTaskType, TDataType>.Add(ATaskType: TTaskType;
  ADataType: TDataType);
begin
  FSuspensionQueue.Push( TItem<TTaskType,TDataType>.Create(ATaskType, ADataType) );
end;

procedure TTaskQueue<TTaskType, TDataType>.Clear;
var
  Item : TItem<TTaskType,TDataType>;
begin
  while FSuspensionQueue.IsEmpty = false do begin
    Item := FSuspensionQueue.Pop;
    Item.Free;
  end;
end;

constructor TTaskQueue<TTaskType, TDataType>.Create;
begin
  inherited;

  FSuspensionQueue := TSuspensionQueue<TItem<TTaskType, TDataType>>.Create;

  FSimpleThread := TSimpleThread.Create('TTaskQueue', on_FSimpleThread_Execute);
  FSimpleThread.FreeOnTerminate := false;
end;

destructor TTaskQueue<TTaskType, TDataType>.Destroy;
begin
  Clear;

  FSimpleThread.TerminateNow;

  FreeAndNil(FSuspensionQueue);
  FreeAndNil(FSimpleThread);

  inherited;
end;

procedure TTaskQueue<TTaskType, TDataType>.on_FSimpleThread_Execute(
  ASimpleThread: TSimpleThread);
var
  Item : TItem<TTaskType,TDataType>;
begin
  while ASimpleThread.Terminated = false do begin
    Item := FSuspensionQueue.Pop;
    if Assigned(FOnTask) then FOnTask(Item.FTaksType, Item.FDataType);
  end;
end;

end.
