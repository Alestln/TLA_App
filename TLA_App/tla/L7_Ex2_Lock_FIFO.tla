------------------------ MODULE L7_Ex2_Lock_FIFO ------------------------
(***************************************************************************)
(* Лекция 7. Пример 2г. Честный замок с очередью (Ticket Lock / FIFO).     *)
(* Достаточно СЛАБОЙ справедливости (WF).                                  *)
(*                                                                         *)
(*   Request:  встал в конец очереди (взял талончик)                       *)
(*   Acquire:  вхожу, только если я ПЕРВЫЙ в очереди                       *)
(*   Release:  выхожу и удаляю себя из начала очереди                      *)
(*                                                                         *)
(* Почему теперь хватает WF? Когда p стал первым в очереди, никто другой   *)
(* не может «перехватить» замок, поэтому Acquire(p) возможен НЕПРЕРЫВНО    *)
(* до тех пор, пока p его не выполнит.                                     *)
(*                                                                         *)
(* Ожидание: 0 ошибок для 3 потоков.                                       *)
(***************************************************************************)
EXTENDS Sequences, FiniteSets

CONSTANT Procs

VARIABLES
    pc,         \* pc[p] : "idle" | "wait" | "cs"
    queue       \* очередь талончиков: <<p2, p1, ...>>

vars == <<pc, queue>>

TypeOK ==
    /\ pc    \in [Procs -> {"idle", "wait", "cs"}]
    /\ queue \in Seq(Procs)

Init ==
    /\ pc    = [p \in Procs |-> "idle"]
    /\ queue = <<>>

Request(p) ==
    /\ pc[p] = "idle"
    /\ queue' = Append(queue, p)            \* встал в конец очереди
    /\ pc'    = [pc EXCEPT ![p] = "wait"]

Acquire(p) ==
    /\ pc[p] = "wait"
    /\ queue # <<>>
    /\ Head(queue) = p                      \* моя очередь
    /\ pc' = [pc EXCEPT ![p] = "cs"]
    /\ UNCHANGED queue

Release(p) ==
    /\ pc[p] = "cs"
    /\ queue' = Tail(queue)                 \* ушёл из начала очереди
    /\ pc'    = [pc EXCEPT ![p] = "idle"]

Next == \E p \in Procs : Request(p) \/ Acquire(p) \/ Release(p)

Fairness ==
    \A p \in Procs : WF_vars(Acquire(p)) /\ WF_vars(Release(p))   \* только WF!

Spec == Init /\ [][Next]_vars /\ Fairness

-----------------------------------------------------------------------------
MutualExclusion ==
    \A p, q \in Procs : (p # q) => ~(pc[p] = "cs" /\ pc[q] = "cs")

NoStarvation ==
    \A p \in Procs : (pc[p] = "wait") ~> (pc[p] = "cs")

=============================================================================

