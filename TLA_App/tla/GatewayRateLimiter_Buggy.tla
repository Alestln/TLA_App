--------------------- MODULE GatewayRateLimiter_Buggy ---------------------
EXTENDS Integers, Sequences, FiniteSets, TLC

CONSTANTS 
    Clients,        \* Множество клиентов, например: {c1, c2, c3}
    MaxSessions     \* Максимальный лимит параллельных сессий, например: 2

VARIABLES 
    activeSessions, \* Глобальный счетчик сессий шлюза
    clientStatus    \* Локальное состояние каждого клиента: "idle", "checked", "in_session"

vars == <<activeSessions, clientStatus>>

(* Початковий стан системи (Init) *)
Init == 
    /\ activeSessions = 0
    /\ clientStatus = [c \in Clients |-> "idle"]

(* Действие 1: Клиент проверяет лимит — Time-of-Check (TOC) *)
(* ВНИМАНИЕ: activeSessions НЕ увеличивается, меняется только локальный статус клиента! *)
ClientCheck(c) ==
    /\ clientStatus[c] = "idle"
    /\ activeSessions < MaxSessions
    /\ clientStatus' = [clientStatus EXCEPT ![c] = "checked"]
    /\ UNCHANGED activeSessions

(* Действие 2: Клиент входит в сессию — Time-of-Use (TOU) *)
ClientEnter(c) ==
    /\ clientStatus[c] = "checked"
    /\ clientStatus' = [clientStatus EXCEPT ![c] = "in_session"]
    /\ activeSessions' = activeSessions + 1

(* Действие 3: Клиент завершает сессию и освобождает слот *)
ClientLeave(c) ==
    /\ clientStatus[c] = "in_session"
    /\ clientStatus' = [clientStatus EXCEPT ![c] = "idle"]
    /\ activeSessions' = activeSessions - 1

(* Действие 4: Отклонение запроса, если лимит исчерпан *)
ClientReject(c) ==
    /\ clientStatus[c] = "idle"
    /\ activeSessions >= MaxSessions
    /\ UNCHANGED vars

(* Отношение перехода состояний (Next): любой доступный переход *)
Next == 
    \E c \in Clients:
        \/ ClientCheck(c)
        \/ ClientEnter(c)
        \/ ClientLeave(c)
        \/ ClientReject(c)

-----------------------------------------------------------------------------
(* Инвариант типизации (TypeOK) *)
TypeOK ==
    /\ activeSessions \in 0..Cardinality(Clients)
    /\ \A c \in Clients: clientStatus[c] \in {"idle", "checked", "in_session"}

(* ИНВАРИАНТ БЕЗОПАСНОСТИ (Safety Invariant): *)
(* Политика безопасности: количество сессий НИКОГДА не должно превышать MaxSessions *)
SecurityInvariant == 
    activeSessions <= MaxSessions

=============================================================================
