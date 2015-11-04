unit Scheduler;

interface

uses
  RyuLibBase, SimpleThread, DynamicQueue, QueryPerformance,
  Windows, SysUtils, Classes, SyncObjs;

const
  DEFAULT_INTERVAL = 10;

type
  // TODO: TPacketProcessor, TaskQueue, TWorker, TScheduler ������ ���� �Ǵ� ����
  // TODO: TaskQueue, TWorker, TScheduler ������ ����

  {*
    ó���ؾ� �� �۾��� ť�� �ְ� ���ʷ� �����Ѵ�.
    �۾��� ������ ������ �����带 �̿��ؼ� �񵿱�� �����Ѵ�.
    �۾� ��û�� �پ��� �����忡�� ����Ǵµ�, �������� ������ �ʿ� �� �� ����Ѵ�.
    ��û �� �۾��� ��û�� ������� ������ �����忡�� ����Ǿ�� �� �� ����Ѵ�.  (�񵿱� ����)
    TaskQueue �� �ٸ� ���� TTimer�� ���� �ֱ����� �ð����� �̺�Ʈ�� �߻��Ѵٴ� ���̴�.
  }
  TScheduler = class
  private
    FCS : TCriticalSection;
    FTasks : TDynamicQueue;
    procedure do_Tasks;
    function get_Task:TObject;
  private
    TickCount, OldTick, Tick : Cardinal;
    procedure do_Timer;
  private
    FSimpleThread : TSimpleThread;
    procedure on_Repeat(Sender:TObject);
  private
    FOnTask: TDataAndTagEvent;
    FOnTerminate: TNotifyEvent;
    FOnTimer: TNotifyEvent;
    FInterval: integer;
    FIsStarted: boolean;
    FOnStop: TNotifyEvent;
    FOnStart: TNotifyEvent;
    procedure SetInterval(const Value: integer);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;

    procedure Start;
    procedure Stop;

    procedure Add(AData:pointer; ASize:integer); overload;
    procedure Add(AData:pointer; ASize:integer; ATag:pointer); overload;
    procedure Add(ATag:pointer); overload;
  public
    property IsStarted : boolean read FIsStarted;
    property Interval : integer read FInterval write SetInterval;
  public
    property OnStart : TNotifyEvent read FOnStart write FOnStart;
    property OnStop : TNotifyEvent read FOnStop write FOnStop;
    property OnTimer : TNotifyEvent read FOnTimer write FOnTimer;
    property OnTask : TDataAndTagEvent read FOnTask write FOnTask;
    property OnTerminate : TNotifyEvent read FOnTerminate write FOnTerminate;
  end;

implementation

type
  TTaskType = (ttData, ttStart, ttStop);

  TTask = class
  private
    FTaskType : TTaskType;
    FData : pointer;
    FSize : integer;
    FTag : pointer;
  public
    constructor Create(ATaskType:TTaskType); reintroduce; overload;
    constructor Create(AData:pointer; ASize:integer; ATag:pointer); reintroduce; overload;
    destructor Destroy; override;
  end;

{ TTask }

constructor TTask.Create(AData: pointer; ASize: integer; ATag: pointer);
begin
  inherited Create;

  FTaskType := ttData;

  FSize := ASize;

  if FSize <= 0 then begin
    FData := nil;
  end else begin
    GetMem(FData, FSize);
    Move(AData^, FData^, FSize);
  end;

  FTag := ATag;
end;

constructor TTask.Create(ATaskType: TTaskType);
begin
  inherited Create;

  FTaskType := ATaskType;

  FData := nil;
  FSize := 0;
  FTag := 0;
end;

destructor TTask.Destroy;
begin
  if FData <> nil then FreeMem(FData);

  inherited;
end;

{ TScheduler }

procedure TScheduler.Add(AData: pointer; ASize: integer);
begin
  FCS.Acquire;
  try
    FTasks.Push( TTask.Create(AData, ASize, nil) );
    FSimpleThread.WakeUp;
  finally
    FCS.Release;
  end;
end;

procedure TScheduler.Add(AData: pointer; ASize: integer; ATag: pointer);
begin
  FCS.Acquire;
  try
    FTasks.Push( TTask.Create(AData, ASize, ATag) );
    FSimpleThread.WakeUp;
  finally
    FCS.Release;
  end;
end;

procedure TScheduler.Add(ATag: pointer);
begin
  FCS.Acquire;
  try
    FTasks.Push( TTask.Create(nil, 0, ATag) );
    FSimpleThread.WakeUp;
  finally
    FCS.Release;
  end;
end;

procedure TScheduler.Clear;
var
  Task : TTask;
begin
  FCS.Acquire;
  try
    while FTasks.Pop(Pointer(Task)) do Task.Free;
  finally
    FCS.Release;
  end;
end;

constructor TScheduler.Create;
begin
  inherited;

  FIsStarted := false;
  FInterval := DEFAULT_INTERVAL;

  FCS := TCriticalSection.Create;
  FTasks := TDynamicQueue.Create(false);

  FSimpleThread := TSimpleThread.Create(on_Repeat);
end;

destructor TScheduler.Destroy;
begin
  Clear;

  FSimpleThread.Terminate;

  inherited;
end;

procedure TScheduler.do_Tasks;
var
  Task : TTask;
begin
  Task := Pointer( get_Task );

  while Task <> nil do begin
    try
      case Task.FTaskType of
        ttData: if Assigned(FOnTask) then FOnTask(Self, Task.FData, Task.FSize, Task.FTag);

        ttStart: begin
          FIsStarted := true;
          if Assigned(FOnStart) then FOnStart(Self);
        end;

        ttStop: begin
          FIsStarted := false;
          if Assigned(FOnStop) then FOnStop(Self);
        end;
      end;
    finally
      Task.Free;
    end;

    Task := Pointer( get_Task );
  end;
end;

procedure TScheduler.do_Timer;
begin
  Tick := GetTick;

  if FIsStarted = false then begin
    OldTick := Tick;
    TickCount := 0;
    Exit;
  end;

  if Tick > OldTick then begin
    TickCount := TickCount + (Tick-OldTick);
    if TickCount >= FInterval then begin
      TickCount := 0;
      if Assigned(FOnTimer) then FOnTimer(Self);
    end;
  end;

  OldTick := Tick;
end;

function TScheduler.get_Task: TObject;
begin
  Result := nil;

  FCS.Acquire;
  try
    FTasks.Pop(Pointer(Result));
  finally
    FCS.Release;
  end;
end;

procedure TScheduler.on_Repeat(Sender: TObject);
var
  SimpleThread : TSimpleThread absolute Sender;
begin
  TickCount := 0;

  OldTick := GetTick;

  while not SimpleThread.Terminated do begin
    do_Tasks;
    do_Timer;

    SimpleThread.Sleep(1);
  end;

  Clear;

  if Assigned(FOnTerminate) then FOnTerminate(Self);

//  FreeAndNil(FCS);
//  FreeAndNil(FTasks);
end;

procedure TScheduler.SetInterval(const Value: integer);
begin
  FInterval := Value;
end;

procedure TScheduler.Start;
begin
  FCS.Acquire;
  try
    FTasks.Push( TTask.Create(ttStart) );
    FSimpleThread.WakeUp;
  finally
    FCS.Release;
  end;
end;

procedure TScheduler.Stop;
begin
  // TODO: ����Ǹ� �ٷ� ��� ������ ó���� ����ǵ��� (�÷��� ����)

  FCS.Acquire;
  try
    FTasks.Push( TTask.Create(ttStop) );
    FSimpleThread.WakeUp;
  finally
    FCS.Release;
  end;
end;

end.
