------------------- MODULE L7_Ex4_RW_WriterPriority -------------------
(***************************************************************************)
(* Лекция 7. Пример 4б. Читатели-писатели с ПРИОРИТЕТОМ ПИСАТЕЛЯ.          *)
(*                                                                         *)
(* Отличие от L7_Ex4_RW_Naive — ОДНО условие в StartRead:                  *)
(*                                                                         *)
(*   новый читатель НЕ входит, если какой-то писатель уже ЖДЁТ.            *)
(*                                                                         *)
(* Тогда «поток» читателей иссякает: старые дочитывают (WF на EndRead),    *)
(* новые не заходят, и StartWrite становится возможным НЕПРЕРЫВНО —        *)
(* слабой справедливости достаточно.                                       *)
(* Так устроен ReaderWriterLockSlim в .NET.                                *)
(*                                                                         *)
(* Ожидание: 0 ошибок (RWExclusion и WriterProgress выполняются).          *)
(***************************************************************************)
EXTENDS FiniteSets

CONSTANTS Readers, Writers

VARIABLES rpc, wpc

vars == <<rpc, wpc>>

TypeOK ==
    /\ rpc \in [Readers -> {"idle", "reading"}]
    /\ wpc \in [Writers -> {"idle", "wait", "writing"}]

ActiveReaders  == {r \in Readers : rpc[r] = "reading"}
SomeoneWrites  == \E w \in Writers : wpc[w] = "writing"
WriterWaiting  == \E w \in Writers : wpc[w] = "wait"

Init ==
    /\ rpc = [r \in Readers |-> "idle"]
    /\ wpc = [w \in Writers |-> "idle"]

StartRead(r) ==
    /\ rpc[r] = "idle"
    /\ ~SomeoneWrites
    /\ ~WriterWaiting                       \* <- НОВОЕ: уступаем ждущему писателю
    /\ rpc' = [rpc EXCEPT ![r] = "reading"]
    /\ UNCHANGED wpc

EndRead(r) ==
    /\ rpc[r] = "reading"
    /\ rpc' = [rpc EXCEPT ![r] = "idle"]
    /\ UNCHANGED wpc

WantWrite(w) ==
    /\ wpc[w] = "idle"
    /\ wpc' = [wpc EXCEPT ![w] = "wait"]
    /\ UNCHANGED rpc

StartWrite(w) ==
    /\ wpc[w] = "wait"
    /\ ActiveReaders = {}
    /\ ~SomeoneWrites
    /\ wpc' = [wpc EXCEPT ![w] = "writing"]
    /\ UNCHANGED rpc

EndWrite(w) ==
    /\ wpc[w] = "writing"
    /\ wpc' = [wpc EXCEPT ![w] = "idle"]
    /\ UNCHANGED rpc

Next ==
    \/ \E r \in Readers : StartRead(r) \/ EndRead(r)
    \/ \E w \in Writers : WantWrite(w) \/ StartWrite(w) \/ EndWrite(w)

Fairness ==
    /\ \A r \in Readers : WF_vars(EndRead(r))
    /\ \A w \in Writers : WF_vars(StartWrite(w)) /\ WF_vars(EndWrite(w))

Spec == Init /\ [][Next]_vars /\ Fairness

-----------------------------------------------------------------------------
RWExclusion ==
    \A w \in Writers : wpc[w] = "writing" =>
        /\ ActiveReaders = {}
        /\ \A v \in Writers \ {w} : wpc[v] # "writing"

WriterProgress == \A w \in Writers : (wpc[w] = "wait") ~> (wpc[w] = "writing")

=============================================================================

