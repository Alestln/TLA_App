----------------------- MODULE L7_Ex4_RW_Naive -----------------------
(***************************************************************************)
(* Лекция 7. Пример 4а. Читатели-писатели (Readers-Writers), наивный замок.*)
(*                                                                         *)
(* Практика: кэш прав доступа / список отозванных токенов. Читают его      *)
(* тысячи запросов в секунду, а администратор изредка ЗАПИСЫВАЕТ           *)
(* (например, блокирует скомпрометированный аккаунт).                      *)
(*                                                                         *)
(*   Читатель: входит, если сейчас никто не пишет. Читатели не мешают      *)
(*             друг другу — читать могут несколько одновременно.           *)
(*   Писатель: входит, только если НЕТ ни читателей, ни другого писателя.  *)
(*                                                                         *)
(* Ожидание: Safety (RWExclusion) выполняется, но WriterProgress           *)
(* НАРУШЕНО (цикл «Back to state N»): читатели сменяют друг друга          *)
(* «внахлёст», их число никогда не падает до нуля, и писатель ждёт вечно.  *)
(* Здесь не поможет даже SF: StartWrite в этом цикле не возможен НИ РАЗУ.  *)
(* Лечится только изменением алгоритма (см. L7_Ex4_RW_WriterPriority).     *)
(***************************************************************************)
EXTENDS FiniteSets

CONSTANTS Readers, Writers

VARIABLES
    rpc,        \* rpc[r] : "idle" | "reading"
    wpc         \* wpc[w] : "idle" | "wait" | "writing"

vars == <<rpc, wpc>>

TypeOK ==
    /\ rpc \in [Readers -> {"idle", "reading"}]
    /\ wpc \in [Writers -> {"idle", "wait", "writing"}]

ActiveReaders == {r \in Readers : rpc[r] = "reading"}
SomeoneWrites == \E w \in Writers : wpc[w] = "writing"

Init ==
    /\ rpc = [r \in Readers |-> "idle"]
    /\ wpc = [w \in Writers |-> "idle"]

\* ---------- читатели ----------
StartRead(r) ==
    /\ rpc[r] = "idle"
    /\ ~SomeoneWrites                       \* наивно: смотрим только на активного писателя
    /\ rpc' = [rpc EXCEPT ![r] = "reading"]
    /\ UNCHANGED wpc

EndRead(r) ==
    /\ rpc[r] = "reading"
    /\ rpc' = [rpc EXCEPT ![r] = "idle"]
    /\ UNCHANGED wpc

\* ---------- писатели ----------
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

\* Даже СИЛЬНАЯ справедливость SF для StartWrite здесь НЕ спасает писателя:
\* читатели идут «внахлёст» (1 -> 2 -> 1 -> 2), и окно ActiveReaders = {} не открывается НИ РАЗУ!
Fairness ==
    /\ \A r \in Readers : WF_vars(EndRead(r))
    /\ \A w \in Writers : SF_vars(StartWrite(w)) /\ WF_vars(EndWrite(w))

Spec == Init /\ [][Next]_vars /\ Fairness

-----------------------------------------------------------------------------
\* SAFETY: пока кто-то пишет, никто больше не читает и не пишет
RWExclusion ==
    \A w \in Writers : wpc[w] = "writing" =>
        /\ ActiveReaders = {}
        /\ \A v \in Writers \ {w} : wpc[v] # "writing"

\* LIVENESS: писатель, который ждёт, когда-нибудь запишет
WriterProgress == \A w \in Writers : (wpc[w] = "wait") ~> (wpc[w] = "writing")

=============================================================================

