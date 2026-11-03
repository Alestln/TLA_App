-------------------- MODULE L7_Ex2_Lock_NoFairness --------------------
(***************************************************************************)
(* Лекция 7. Пример 2а. Обычный замок (как lock / Monitor в C#),           *)
(* справедливость НЕ задана.                                               *)
(*                                                                         *)
(*   // поток p:                                                           *)
(*   Request:  захотел войти                      idle -> wait             *)
(*   Acquire:  если замок свободен — взял его     wait -> cs               *)
(*   Release:  отпустил замок                     cs   -> idle             *)
(*                                                                         *)
(* Safety:   MutualExclusion — выполняется.                                *)
(* Liveness: NoStarvation — «каждый, кто ждёт, когда-нибудь войдёт».       *)
(*                                                                         *)
(* Ожидание: NoStarvation НАРУШЕНО, трасса заканчивается «Stuttering»:     *)
(* поток встал в ожидание, замок свободен, а система просто остановилась.  *)
(***************************************************************************)
EXTENDS FiniteSets

CONSTANT Procs

VARIABLES
    pc,         \* pc[p] : "idle" | "wait" | "cs"
    locked      \* занят ли замок

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
    /\ ~locked                          \* атомарный test-and-set, как Monitor.Enter
    /\ locked' = TRUE
    /\ pc'     = [pc EXCEPT ![p] = "cs"]

Release(p) ==
    /\ pc[p] = "cs"
    /\ locked' = FALSE
    /\ pc'     = [pc EXCEPT ![p] = "idle"]

Next == \E p \in Procs : Request(p) \/ Acquire(p) \/ Release(p)

Spec == Init /\ [][Next]_vars                     \* справедливости НЕТ

-----------------------------------------------------------------------------
MutualExclusion ==
    \A p, q \in Procs : (p # q) => ~(pc[p] = "cs" /\ pc[q] = "cs")

\* «Для каждого потока: если он ждёт, то когда-нибудь окажется в КС»
NoStarvation ==
    \A p \in Procs : (pc[p] = "wait") ~> (pc[p] = "cs")

=============================================================================

