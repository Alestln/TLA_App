------------------------- MODULE L7_Ex2_Lock_SF -------------------------
(***************************************************************************)
(* Лекция 7. Пример 2в. Тот же замок + СИЛЬНАЯ справедливость (SF)         *)
(* для захвата замка.                                                      *)
(*                                                                         *)
(*   SF_vars(Acquire(p)):                                                  *)
(*     «если Acquire(p) возможен СНОВА И СНОВА (бесконечно часто, пусть    *)
(*      даже с перерывами), то p когда-нибудь его выполнит».               *)
(*                                                                         *)
(* Ожидание: 0 ошибок. НО! SF — это ПРЕДПОЛОЖЕНИЕ о планировщике / замке,  *)
(* а не свойство нашего кода. lock / Monitor в .NET такого НЕ обещает      *)
(* (он не FIFO). Чтобы не зависеть от удачи, нужен честный алгоритм:       *)
(* см. L7_Ex2_Lock_FIFO.                                                   *)
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

Fairness ==
    \A p \in Procs : SF_vars(Acquire(p)) /\ WF_vars(Release(p))   \* <- SF вместо WF

Spec == Init /\ [][Next]_vars /\ Fairness

-----------------------------------------------------------------------------
MutualExclusion ==
    \A p, q \in Procs : (p # q) => ~(pc[p] = "cs" /\ pc[q] = "cs")

NoStarvation ==
    \A p \in Procs : (pc[p] = "wait") ~> (pc[p] = "cs")

=============================================================================

