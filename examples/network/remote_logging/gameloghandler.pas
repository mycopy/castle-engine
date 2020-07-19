{
  Copyright 2020-2020 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Log handler sending logs to server using asynchronous HTTP POST (TLogHandler). }
unit GameLogHandler;

interface

uses SysUtils, Math, Classes,
  CastleWindow, CastleLog, CastleApplicationProperties, CastleKeysMouse,
  CastleDownload, CastleClassUtils;

type
  { Log handler sending logs to server using asynchronous HTTP POST. }
  TLogHandler = class(TComponent)
  strict private
    InsideLogCallback: Boolean;
    ProcessId: Cardinal;
    procedure HttpPostFinish(const Sender: TCastleDownload);
  public
    constructor Create(AOwner: TComponent); override;
    procedure LogCallback(const Message: String);
  end;

implementation

uses CastleUtils, CastleStringUtils;

constructor TLogHandler.Create(AOwner: TComponent);
begin
  inherited;
  { This "process id" is not used for any OS process management.
    It's only a unique process id, hopefully unique across all current
    application instances on all systems.
    So we can just choose it using Random, no need to use Unix "pid" or
    equivalent WinAPI function for this. }
  ProcessId := Random(1000);
end;

procedure TLogHandler.LogCallback(const Message: String);

  { Send, using HTTP post, one parameter. }
  procedure HttpPost(const Url: String; const ParameterKey, ParameterValue: String);
  var
    Download: TCastleDownload;
  begin
    Download := TCastleDownload.Create(Application);
    Download.Url := Url;
    Download.PostData.Values[ParameterKey] := ParameterValue;
    Download.HttpMethod := hmPost;
    Download.OnFinish := @HttpPostFinish;
    Download.Start;
  end;

var
  SendMessage: String;
begin
  { Use InsideLogCallback to prevent from infinite recursion,
    in case anything inside would also cause WritelnLog. }
  if InsideLogCallback then Exit;

  { Do not send messages about network communication, as they would cause infinite recursion too. }
  if IsPrefix('Network:', Message) then
    Exit;

  InsideLogCallback := true;
  try
    // We use TrimRight to strip traling newline
    SendMessage := ApplicationName + '[' + IntToStr(ProcessId) + '] ' + TrimRight(Message);
    HttpPost('https://castle-engine.io/cge_logger.php', 'message', SendMessage);
  finally InsideLogCallback := false end;
end;

procedure TLogHandler.HttpPostFinish(const Sender: TCastleDownload);
begin
  case Sender.Status of
    dsSuccess:
      Writeln(ErrOutput, Format('Posted log to "%s" with response: %s', [
        Sender.Url,
        StreamToString(Sender.Contents)
      ]));
    dsError:
      Writeln(ErrOutput, Format('Posted log to "%s" with error: %s', [
        Sender.Url,
        Sender.ErrorMessage
      ]));
    else
      raise EInternalError.Create('No other status is possible when download finished');
  end;
end;

end.