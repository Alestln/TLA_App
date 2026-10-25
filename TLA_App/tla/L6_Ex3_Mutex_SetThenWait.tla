---------------------- MODULE L6_Ex3_Mutex_SetThenWait ----------------------
(***************************************************************************)
(* Лекция 6. Пример 3. Попытка №2: сначала поднять флаг, потом ждать.      *)
(*                                                                         *)
(*   flag[me] = true;          // 1. СНАЧАЛА повесил табличку              *)
(*   while (flag[other]) { }   // 2. ПОТОМ жду, пока другой уйдёт          *)
(*   ... критическая секция ...                                            *)
(*   flag[me] = false;                                                     *)
(*                                                                         *)
(* Ожидание: MutualExclusion СОБЛЮДЁН, но TLC находит DEADLOCK:            *)
(* оба повесили таблички и вечно ждут друг друга.                          *)
(***************************************************************************)
EXTENDS FiniteSets

CONSTANT Procs

VARIABLES
    flag,                       \* flag[p] = TRUE  <=> p хочет войти / находится в КС
    pc                          \* pc[p] : "idle" | "wait" | "cs"

vars == <<flag, pc>>

TypeOK ==
    /\ flag \in [Procs -> BOOLEAN]
    /\ pc   \in [Procs -> {"idle", "wait", "cs"}]

Init ==
    /\ flag = [p \in Procs |-> FALSE]
    /\ pc   = [p \in Procs |-> "idle"]

\* 1. Поднимаем флаг: «я хочу войти»
Want(p) ==
    /\ pc[p] = "idle"
    /\ flag' = [flag EXCEPT ![p] = TRUE]
    /\ pc'   = [pc   EXCEPT ![p] = "wait"]

\* 2. Входим, только когда ни у кого другого нет флага
Enter(p) ==
    /\ pc[p] = "wait"
    /\ \A q \in Procs \ {p} : flag[q] = FALSE
    /\ pc' = [pc EXCEPT ![p] = "cs"]
    /\ UNCHANGED flag

\* 3. Выходим
Exit(p) ==
    /\ pc[p] = "cs"
    /\ flag' = [flag EXCEPT ![p] = FALSE]
    /\ pc'   = [pc   EXCEPT ![p] = "idle"]

Next == \E p \in Procs : Want(p) \/ Enter(p) \/ Exit(p)

-----------------------------------------------------------------------------
MutualExclusion ==
    \A p, q \in Procs : (p # q) => ~(pc[p] = "cs" /\ pc[q] = "cs")

=============================================================================
