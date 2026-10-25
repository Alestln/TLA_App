--------------------- MODULE L6_Ex4_Transfer_Deadlock ---------------------
(***************************************************************************)
(* Лекция 6. Пример 4 (ошибочный). Классический deadlock двух замков.      *)
(*                                                                         *)
(* Поток t1: перевод со счёта 1 на счёт 2 -> lock(1), потом lock(2)        *)
(* Поток t2: перевод со счёта 2 на счёт 1 -> lock(2), потом lock(1)        *)
(*                                                                         *)
(* C#:  lock (from) { lock (to) { from.Balance -= x; to.Balance += x; } }  *)
(*                                                                         *)
(* Ожидание: TLC находит "Deadlock reached":                               *)
(*   t1 держит замок 1 и ждёт 2, t2 держит замок 2 и ждёт 1.               *)
(***************************************************************************)
EXTENDS Naturals

Threads == {"t1", "t2"}
Locks   == {1, 2}                       \* замок = номер счёта

From == [t1 |-> 1, t2 |-> 2]            \* откуда переводим
To   == [t1 |-> 2, t2 |-> 1]            \* куда переводим

\* Порядок захвата замков: КАК В КОДЕ — сначала from, потом to
First  == From
Second == To

VARIABLES
    owner,                              \* owner[l] = поток, держащий замок l, или "free"
    pc                                  \* pc[t] : "start" | "has_first" | "has_both" | "done"

vars == <<owner, pc>>

TypeOK ==
    /\ owner \in [Locks -> Threads \cup {"free"}]
    /\ pc    \in [Threads -> {"start", "has_first", "has_both", "done"}]

Init ==
    /\ owner = [l \in Locks |-> "free"]
    /\ pc    = [t \in Threads |-> "start"]

\* lock(First[t]) — разрешено, только если замок свободен
TakeFirst(t) ==
    /\ pc[t] = "start"
    /\ owner[First[t]] = "free"
    /\ owner' = [owner EXCEPT ![First[t]] = t]
    /\ pc'    = [pc    EXCEPT ![t] = "has_first"]

\* lock(Second[t])
TakeSecond(t) ==
    /\ pc[t] = "has_first"
    /\ owner[Second[t]] = "free"
    /\ owner' = [owner EXCEPT ![Second[t]] = t]
    /\ pc'    = [pc    EXCEPT ![t] = "has_both"]

\* Перевод выполнен, отпускаем оба замка (EXCEPT с двумя ключами сразу)
Release(t) ==
    /\ pc[t] = "has_both"
    /\ owner' = [owner EXCEPT ![First[t]] = "free", ![Second[t]] = "free"]
    /\ pc'    = [pc    EXCEPT ![t] = "done"]

Finished    == \A t \in Threads : pc[t] = "done"
Terminating == Finished /\ UNCHANGED vars    \* нормальное завершение — не deadlock

Next ==
    \/ \E t \in Threads : TakeFirst(t) \/ TakeSecond(t) \/ Release(t)
    \/ Terminating

-----------------------------------------------------------------------------
\* Безопасность замков: в момент перевода поток реально держит оба замка
LockSafety ==
    \A t \in Threads : pc[t] = "has_both" =>
        (owner[First[t]] = t /\ owner[Second[t]] = t)

=============================================================================
