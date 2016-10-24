unit TaskQueue;

interface

uses
  DebugTools, RyuLibBase, SimpleThread, DynamicQueue, QueryPerformance,
  SysUtils, Classes;

const
  DEFAULT_INTERVAL = 10;

type
  TTaskEnvet<TTaskType, TDataType> = procedure (ASender:Tobject; ATaskType:TTaskType; ADataType:TDataType) of object;
  TTimerEvent = procedure (ASender:Tobject; ATick:integer) of object;

  TItem<TTaskType, TDataType> = class
  private
    FTaksType : TTaskType;
    FData : TDataType;
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
    FIsStarted : boolean;
    FDynamicQueue : TDynamicQueue;
    FOldTick : int64;
    procedure do_Timer;
  private
    FSimpleThread : TSimpleThread;
    procedure on_FSimpleThread_Execute(ASimpleThread:TSimpleThread);
  private
    FOnTask: TTaskEnvet<TTaskType, TDataType>;
    FInterval: integer;
    FOnTimer: TTimerEvent;
    procedure SetInterval(const Value: integer);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Start;
    procedure Stop;

    procedure Add(ATaskType:TTaskType; ADataType:TDataType);
  public
  public
    property Interval : integer read FInterval write SetInterval;
    property OnTask : TTaskEnvet<TTaskType, TDataType> read FOnTask write FOnTask;
    property OnTimer : TTimerEvent read FOnTimer write FOnTimer;
  end;

implementation

{ TItem<TTaskType, TDataType> }

constructor TItem<TTaskType, TDataType>.Create(ATaskType: TTaskType;
  ADataType: TDataType);
begin
  FTaksType := ATaskType;
  FData := ADataType;
end;

{ TTaskQueue<TTaskType, TDataType> }

procedure TTaskQueue<TTaskType, TDataType>.Add(ATaskType: TTaskType;
  ADataType: TDataType);
begin
  FDynamicQueue.Push( TItem<TTaskType,TDataType>.Create(ATaskType, ADataType) );
  FSimpleThread.WakeUp;
end;

procedure TTaskQueue<TTaskType, TDataType>.SetInterval(const Value: integer);
begin
  FInterval := Value;
end;

procedure TTaskQueue<TTaskType, TDataType>.Start;
begin
  FOldTick := GetTick;
  FIsStarted := true;

  FSimpleThread.WakeUp;
end;

procedure TTaskQueue<TTaskType, TDataType>.Stop;
var
  Item : TItem<TTaskType,TDataType>;
begin
  FIsStarted := false;

  while FDynamicQueue.Pop( Pointer(Item) ) do Item.Free;
end;

constructor TTaskQueue<TTaskType, TDataType>.Create;
begin
  inherited;

  FIsStarted := false;
  FInterval := DEFAULT_INTERVAL;

  FDynamicQueue := TDynamicQueue.Create(true);

  FSimpleThread := TSimpleThread.Create('TTaskQueue', on_FSimpleThread_Execute);
  FSimpleThread.FreeOnTerminate := false;
end;

destructor TTaskQueue<TTaskType, TDataType>.Destroy;
begin
  Stop;

  FSimpleThread.TerminateNow;

  FreeAndNil(FDynamicQueue);
  FreeAndNil(FSimpleThread);

  inherited;
end;

procedure TTaskQueue<TTaskType, TDataType>.do_Timer;
var
  Tick, Term : int64;
begin
  if FIsStarted = false then Exit;

  Tick := GetTick;

  if Tick < FOldTick then begin
    FOldTick := Tick;
  end else begin
    Term := Tick-FOldTick;
    if Term >= FInterval then begin
      FOldTick := Tick;
      if Assigned(FOnTimer) then FOnTimer(Self, Term);
    end;
  end;
end;

procedure TTaskQueue<TTaskType, TDataType>.on_FSimpleThread_Execute(
  ASimpleThread: TSimpleThread);
var
  Item : TItem<TTaskType,TDataType>;
begin
  while ASimpleThread.Terminated = false do begin
    while FDynamicQueue.Pop( Pointer(Item) ) do begin
      try
        if Assigned(FOnTask) then FOnTask(Self, Item.FTaksType, Item.FData);
      finally
        Item.Free;
      end;

      do_Timer;
    end;

    do_Timer;

    if FIsStarted then FSimpleThread.Sleep(5)
    else FSimpleThread.SleepTight;
  end;
end;

end.



