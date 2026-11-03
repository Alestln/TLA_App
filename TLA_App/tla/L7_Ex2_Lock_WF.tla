------------------------- MODULE L7_Ex2_Lock_WF -------------------------
(***************************************************************************)
(* Лекция 7. Пример 2б. Тот же замок + СЛАБАЯ справедливость (WF)          *)
(* для каждого потока.                                                     *)
(*                                                                         *)
(*   WF_vars(Acquire(p)):                                                  *)
(*     «если Acquire(p) возможен НЕПРЕРЫВНО, начиная с какого-то момента,  *)
(*      то p когда-нибудь его выполнит».                                   *)
(*                                                                         *)
(* Ожидание: NoStarvation ВСЁ РАВНО НАРУШЕНО, но трасса уже другая —       *)
(* она заканчивается «Back to state N» (цикл). Поток p1 бесконечно         *)
(* берёт и отпускает замок, а p2 вечно ждёт. Acquire(p2) становится        *)
(* возможным лишь на мгновения (когда замок свободен), а не НЕПРЕРЫВНО,    *)
(* поэтому слабая справедливость ему ничего не обещает.                    *)
(* Это ГОЛОДАНИЕ (starvation): система работает, а один поток — нет.       *)
(***************************************************************************)
EXTENDS FiniteSets

CONSTANT Procs

VARIABLES pc, locked

vars == <<pc, locked>>

TypeOK ==
    /\ pc     \in [Procs -> {"idle", "wait", "cs"}]
    /\ locked \in BOOLEAN

Init ==
    /\ pc     = [p \in Procs |-> "idle"]
    /\ locked = FALSE

Request(p) ==
    /\ pc[p] = "idle"
    /\ pc' = [pc EXCEPT ![p] = "wait"]
    /\ UNCHANGED locked

Acquire(p) ==
    /\ pc[p] = "wait"
    /\ ~locked
    /\ locked' = TRUE
    /\ pc'     = [pc EXCEPT ![p] = "cs"]

Release(p) ==
    /\ pc[p] = "cs"
    /\ locked' = FALSE
    /\ pc'     = [pc EXCEPT ![p] = "idle"]

Next == \E p \in Procs : Request(p) \/ Acquire(p) \/ Release(p)

\* Request НЕ делаем справедливым: поток имеет право вообще не хотеть в КС.
Fairness ==
    \A p \in Procs : WF_vars(Acquire(p)) /\ WF_vars(Release(p))

Spec == Init /\ [][Next]_vars /\ Fairness

-----------------------------------------------------------------------------
MutualExclusion ==
    \A p, q \in Procs : (p # q) => ~(pc[p] = "cs" /\ pc[q] = "cs")

NoStarvation ==
    \A p \in Procs : (pc[p] = "wait") ~> (pc[p] = "cs")

=============================================================================

