--------------------- MODULE GatewayRateLimiter_Fixed ---------------------
EXTENDS Integers, Sequences, FiniteSets, TLC

CONSTANTS 
    Clients,        \* Множество клиентов {c1, c2, c3}
    MaxSessions     \* Максимальный лимит параллельных сессий = 2

VARIABLES 
    activeSessions, \* Глобальный счетчик активных сессий
    clientStatus    \* Состояние клиента: "idle" или "in_session"

vars == <<activeSessions, clientStatus>>

(* Начальное состояние системы (Init) *)
Init == 
    /\ activeSessions = 0
    /\ clientStatus = [c \in Clients |-> "idle"]

(* АТОМАРНЫЙ ВХОД В СЕССИЮ: Проверка лимита и инкремент неделимы! *)
ClientEnterSecure(c) ==
    /\ clientStatus[c] = "idle"
    /\ activeSessions < MaxSessions
    /\ clientStatus' = [clientStatus EXCEPT ![c] = "in_session"]
    /\ activeSessions' = activeSessions + 1

(* Завершение сессии *)
ClientLeave(c) ==
    /\ clientStatus[c] = "in_session"
    /\ clientStatus' = [clientStatus EXCEPT ![c] = "idle"]
    /\ activeSessions' = activeSessions - 1

(* Отклонение запроса: вход невозможен из-за исчерпания квоты *)
ClientReject(c) ==
    /\ clientStatus[c] = "idle"
    /\ activeSessions >= MaxSessions
    /\ UNCHANGED vars

(* Отношение перехода состояний (Next) *)
Next == 
    \E c \in Clients:
        \/ ClientEnterSecure(c)
        \/ ClientLeave(c)
        \/ ClientReject(c)

-----------------------------------------------------------------------------
(* Инвариант типизации *)
TypeOK ==
    /\ activeSessions \in 0..Cardinality(Clients)
    /\ \A c \in Clients: clientStatus[c] \in {"idle", "in_session"}

(* ИНВАРИАНТ БЕЗОПАСНОСТИ: лимит шлюза НИКОГДА не может быть превышен *)
SecurityInvariant == 
    activeSessions <= MaxSessions

=============================================================================
