-------------------- MODULE L7_Ex3_Livelock_Polite --------------------
(***************************************************************************)
(* Лекция 7. Пример 3а. «Вежливые» потоки — СКРЫТАЯ блокировка (livelock). *)
(*                                                                         *)
(* Чиним дедлок попытки 2 из лекции 6 «вежливостью»: увидел, что сосед     *)
(* тоже хочет, — опусти свой флаг, отступи и попробуй снова.               *)
(*                                                                         *)
(*   flag[me] = true;                     // SetFlag     idle    -> check  *)
(*   while (flag[other]) {                // Check       check   -> backoff*)
(*       flag[me] = false;                // Backoff     backoff -> retry  *)
(*       flag[me] = true;                 // Retry       retry   -> check  *)
(*   }                                    // Check       check   -> cs     *)
(*   ... критическая секция ...                                            *)
(*   flag[me] = false;                    // Exit        cs      -> idle   *)
(*                                                                         *)
(* Ожидание:                                                               *)
(*   - MutualExclusion выполняется;                                        *)
(*   - deadlock НЕТ (TLC его не находит: шаги возможны всегда);            *)
(*   - Progress НАРУШЕНО: цикл «Back to state N», в котором оба потока     *)
(*     вечно уступают друг другу и НИКТО не входит в КС.                   *)
(* Это livelock: система крутится, CPU греется, а работа стоит.            *)
(***************************************************************************)
EXTENDS FiniteSets

CONSTANT Procs
ASSUME Cardinality(Procs) = 2

Other(p) == CHOOSE q \in Procs : q # p

VARIABLES flag, pc

vars == <<flag, pc>>

TypeOK ==
    /\ flag \in [Procs -> BOOLEAN]
    /\ pc   \in [Procs -> {"idle", "check", "backoff", "retry", "cs"}]

Init ==
    /\ flag = [p \in Procs |-> FALSE]
    /\ pc   = [p \in Procs |-> "idle"]

SetFlag(p) ==
    /\ pc[p] = "idle"
    /\ flag' = [flag EXCEPT ![p] = TRUE]
    /\ pc'   = [pc   EXCEPT ![p] = "check"]

\* while (flag[other]) — сосед хочет: иду уступать
CheckBusy(p) ==
    /\ pc[p] = "check"
    /\ flag[Other(p)] = TRUE
    /\ pc' = [pc EXCEPT ![p] = "backoff"]
    /\ UNCHANGED flag

\* while (flag[other]) — сосед не хочет: вхожу
CheckFree(p) ==
    /\ pc[p] = "check"
    /\ flag[Other(p)] = FALSE
    /\ pc' = [pc EXCEPT ![p] = "cs"]
    /\ UNCHANGED flag

Backoff(p) ==
    /\ pc[p] = "backoff"
    /\ flag' = [flag EXCEPT ![p] = FALSE]   \* вежливо опускаю флаг
    /\ pc'   = [pc   EXCEPT ![p] = "retry"]

Retry(p) ==
    /\ pc[p] = "retry"
    /\ flag' = [flag EXCEPT ![p] = TRUE]    \* снова поднимаю флаг
    /\ pc'   = [pc   EXCEPT ![p] = "check"]

Exit(p) ==
    /\ pc[p] = "cs"
    /\ flag' = [flag EXCEPT ![p] = FALSE]
    /\ pc'   = [pc   EXCEPT ![p] = "idle"]

Next == \E p \in Procs :
            SetFlag(p) \/ CheckBusy(p) \/ CheckFree(p) \/ Backoff(p) \/ Retry(p) \/ Exit(p)

\* Все шаги, кроме SetFlag, — справедливые: поток, начавший протокол, не «засыпает».
Fairness ==
    \A p \in Procs :
        /\ WF_vars(CheckBusy(p)) /\ WF_vars(CheckFree(p))
        /\ WF_vars(Backoff(p))   /\ WF_vars(Retry(p))
        /\ WF_vars(Exit(p))

Spec == Init /\ [][Next]_vars /\ Fairness

-----------------------------------------------------------------------------
MutualExclusion ==
    \A p, q \in Procs : (p # q) => ~(pc[p] = "cs" /\ pc[q] = "cs")

Trying(p) == pc[p] \in {"check", "backoff", "retry"}

\* Прогресс системы: «если кто-то пытается войти, то КТО-НИБУДЬ войдёт»
Progress == (\E p \in Procs : Trying(p)) ~> (\E p \in Procs : pc[p] = "cs")

\* Отсутствие голодания: «КАЖДЫЙ, кто пытается, войдёт сам»
NoStarvation == \A p \in Procs : Trying(p) ~> (pc[p] = "cs")

=============================================================================

