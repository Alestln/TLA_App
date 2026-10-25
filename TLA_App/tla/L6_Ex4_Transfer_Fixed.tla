---------------------- MODULE L6_Ex4_Transfer_Fixed ----------------------
(***************************************************************************)
(* Лекция 6. Пример 4 (исправленный). Глобальный порядок захвата замков.   *)
(*                                                                         *)
(* Правило: замки ВСЕГДА берутся по возрастанию номера счёта,              *)
(* независимо от направления перевода.                                     *)
(*                                                                         *)
(* C#:  var (a, b) = from.Id < to.Id ? (from, to) : (to, from);            *)
(*      lock (a) { lock (b) { ... } }                                      *)
(*                                                                         *)
(* Отличие от L6_Ex4_Transfer_Deadlock — ТОЛЬКО определения First/Second.  *)
(***************************************************************************)
EXTENDS Naturals

Threads == {"t1", "t2"}
Locks   == {1, 2}

From == [t1 |-> 1, t2 |-> 2]
To   == [t1 |-> 2, t2 |-> 1]

Min(a, b) == IF a < b THEN a ELSE b
Max(a, b) == IF a < b THEN b ELSE a

\* ИСПРАВЛЕНИЕ: сначала меньший номер, потом больший
First  == [t \in Threads |-> Min(From[t], To[t])]
Second == [t \in Threads |-> Max(From[t], To[t])]

VARIABLES owner, pc
vars == <<owner, pc>>

TypeOK ==
    /\ owner \in [Locks -> Threads \cup {"free"}]
    /\ pc    \in [Threads -> {"start", "has_first", "has_both", "done"}]

Init ==
    /\ owner = [l \in Locks |-> "free"]
    /\ pc    = [t \in Threads |-> "start"]

TakeFirst(t) ==
    /\ pc[t] = "start"
    /\ owner[First[t]] = "free"
    /\ owner' = [owner EXCEPT ![First[t]] = t]
    /\ pc'    = [pc    EXCEPT ![t] = "has_first"]

TakeSecond(t) ==
    /\ pc[t] = "has_first"
    /\ owner[Second[t]] = "free"
    /\ owner' = [owner EXCEPT ![Second[t]] = t]
    /\ pc'    = [pc    EXCEPT ![t] = "has_both"]

Release(t) ==
    /\ pc[t] = "has_both"
    /\ owner' = [owner EXCEPT ![First[t]] = "free", ![Second[t]] = "free"]
    /\ pc'    = [pc    EXCEPT ![t] = "done"]

Finished    == \A t \in Threads : pc[t] = "done"
Terminating == Finished /\ UNCHANGED vars

Next ==
    \/ \E t \in Threads : TakeFirst(t) \/ TakeSecond(t) \/ Release(t)
    \/ Terminating

-----------------------------------------------------------------------------
LockSafety ==
    \A t \in Threads : pc[t] = "has_both" =>
        (owner[First[t]] = t /\ owner[Second[t]] = t)

=============================================================================
