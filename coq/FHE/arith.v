Require Import Reals Lra Lia List Permutation.
From mathcomp Require Import common ssreflect fintype bigop ssrnat matrix Rstruct complex seq fingroup.
From mathcomp Require Import ssralg ssrfun.
From mathcomp Require Import generic_quotient ring_quotient.
From mathcomp Require Import poly mxpoly polydiv ssrint zmodp eqtype ssrbool div order.
From mathcomp Require Import ring ssrZ.

Import ssralg.GRing.
Require Import nth_root encode zp_prim_root.

Ltac coq_lra := lra.
From mathcomp Require Import lra.

Set Bullet Behavior "Strict Subproofs".


Local Open Scope ring_scope.


Record ENCODE : Type :=
  mkENCODE
    { clear : {poly int} ;
      scale : nat
    }.

Record FHE : Type := 
  mkFHE
    { q : nat; 
      cypher : {poly {poly 'Z_q}} ;
      norm_bound : R ; 
      noise_bound : R
    }.

Definition FHE_add {q : nat}  (P Q : {poly {poly 'Z_q}} ) := P + Q.

Definition FHE_mult_base {q : nat} (P Q : {poly {poly 'Z_q}} ) := P * Q.

Definition zliftc {q : nat} (c : 'Z_q) : int :=
  if (c <= q/2) then c%:Z else c%:Z - q%:Z.

Lemma zliftc_bound {q : nat} (c : 'Z_q) :
  1 < q ->
  `| zliftc c | <= q/2.
Proof.
  intros.
  rewrite /zliftc.
  case: (boolP (c <= q/2)); intros.
  - by destruct c.
  - destruct c.
    simpl in *.
    move /negP in i.
    assert (m > (Nat.divmod q 1 0 1).1) by lia.
    rewrite Zp_cast // in i0.
    replace `|m-q| with (q - m)%N by (rewrite distnEr; lia).
    assert (q <= 2*(Nat.divmod q 1 0 1).1 + 1).
    {
      move: (Nat.divmod_spec q 1 0 1 (le_refl _)) => /=.
      case: (Nat.divmod q 1 0 1) => /= x u.
      rewrite !Nat.add_0_r.
      move=> [-> ubound].
      destruct u; lia.
    }
    lia.
 Qed.

Lemma modp_small (q : nat) (m : nat) :
  m < (Zp_trunc q).+2 ->
  nat_of_ord (intmul (1 : 'Z_q) (Posz m)) = m.
Proof.
  rewrite /intmul Zp_nat /=.
  by apply/modn_small.
Qed.

Lemma modpp (q : nat) :
  nat_of_ord (intmul (1 : 'Z_q) (Posz (Zp_trunc q).+2)) = 0%nat.
Proof.
  by rewrite /intmul Zp_nat /= modnn.
Qed.

Lemma modpp' (q : nat) :
  1 < q ->
  intmul (1 : 'Z_q) (Posz q) = 0.
Proof.
  intros.
  apply ord_inj. 
  by rewrite /intmul Zp_nat /= Zp_cast // modnn.
Qed.
  
Lemma zliftc_valid {q : nat} (c : 'Z_q) :
  1 < q ->
  (zliftc c) %:~R = c.
Proof.
  intros.
  rewrite /zliftc.
  case: (c <= q/2).
  - destruct c.
    apply ord_inj => /=.
    by rewrite modp_small.
  - destruct c.
    rewrite intrD mulrNz modpp' // oppr0 addr0.
    apply ord_inj => /=.
    by rewrite modp_small.
Qed.

Lemma zliftc_add2 {q : nat} (a b : 'Z_q) :
  1 < q ->
  `|zliftc (a + b)%R -  ((zliftc a) + (zliftc b))%R  | <= q.
Proof.
  have diveq: (Nat.divmod q 1 0 1).1 = (q / 2)%nat by [].

  move=> qbig.
  rewrite /zliftc /=.
  Ltac t1 C :=
    match goal with
    | [|- is_true (leq (absz ?x) _) ] =>
        have ->: x = C by lia
    end.

  Ltac t2 C := t1 C
    ; case: (boolP (((Zp_trunc q).+1 < _ + _))) => // _
                                                  ; (rewrite ?mul0n ?mul1n ?Zp_cast // ?distnn); lia.

  case: (boolP ( (a + b) %% (Zp_trunc q).+2 <= (Nat.divmod q 1 0 1).1)) => ltab
   ; case: (boolP (a <= (Nat.divmod q 1 0 1).1)) => lta
   ; case: (boolP (b <= (Nat.divmod q 1 0 1).1)) => ltb
                                                  ; rewrite modnD // [modn a _]modn_small ?[modn b _]modn_small; try apply ltn_ord.
  - t2 (opp (Posz (muln (leq (S (S (Zp_trunc q))) (addn a b)) (S (S (Zp_trunc q)))))).
  - t2 (add (V:=int_ZmodType) q (opp (Posz (muln (leq (S (S (Zp_trunc q))) (addn a b)) (S (S (Zp_trunc q))))))).
  - t2 (add (V:=int_ZmodType) (Posz q) (opp (Posz (muln (leq (S (S (Zp_trunc q))) (addn a b)) (S (S (Zp_trunc q))))))).
  - have eqq: ((Zp_trunc q).+1 < a + b).
    { move: (Nat.divmod_spec q 1 0 1) lta ltb.
      case: (Nat.divmod q 1 0 1) => /= x u.
      move/(_ (le_n _)) => [eqq1 eqq2] lta ltb.
      rewrite !Nat.add_0_r in eqq1.
      rewrite {1}Zp_cast //.
      destruct u; simpl in *; lia.
    }
    rewrite eqq mul1n.
    rewrite {1}Zp_cast // in eqq.
    rewrite {3}Zp_cast //.
    by t1 (Posz q).
  - case: (boolP ((Zp_trunc q).+1 < a + b)).
    + rewrite mul1n {1}Zp_cast // => ineq2.
      simpl in lta.
      rewrite diveq in lta ltb ltab.
      case: (eqVneq q (nat_of_ord a + nat_of_ord b))%nat =>eqq2.
      * case/negP: ltab.
        by rewrite {3}Zp_cast // {3}eqq2 modnn.
      * suff: 2 * (q / 2)%nat <= q by lia.
        apply /leP.
        by apply Nat.mul_div_le.
    + rewrite mul0n => _.
      t1 (opp (Posz q)).
      by rewrite abszN.
  - t2 (opp (Posz (muln (leq (S (S (Zp_trunc q))) (addn a b)) (S (S (Zp_trunc q)))))).
  - t2 (opp (Posz (muln (leq (S (S (Zp_trunc q))) (addn a b)) (S (S (Zp_trunc q)))))).
  - have eqq: ((Zp_trunc q).+1 < a + b).
    { move: (Nat.divmod_spec q 1 0 1) lta ltb.
      case: (Nat.divmod q 1 0 1) => /= x u.
      move/(_ (le_n _)) => [eqq1 eqq2] lta ltb.
      rewrite !Nat.add_0_r in eqq1.
      rewrite {1}Zp_cast //.
      destruct u; simpl in *; lia.
    }
    rewrite eqq mul1n.
    rewrite {1}Zp_cast // in eqq.
    rewrite {3}Zp_cast //; lia.
Qed.


Lemma bounded_dvdn_cases (a q : nat) :
  1 < q ->
  (q %| a)%N ->
  a < 2 * q ->
  (a == q) || (a == 0%nat).
Proof.
  move=> qbig.
  move/dvdnP => [k ->].
  rewrite ltn_mul2r.
  move/andP=>[_ -].
  case: k; [| case]; lia.
Qed.


Lemma bounded_dvdn (a q : nat) :
  1 < q ->
  (q %| a)%N ->
  a < 2 * q ->
  { c : nat |
    a = (c * q)%N /\ c <= 1}.
Proof.
  move=> qbig qdiva asmall.
  move: (bounded_dvdn_cases a q qbig qdiva asmall).
  case: (eqVneq a q) => /=.
  - exists 1%nat. lia.
  - exists 0%nat. lia.
Qed.

Lemma bounded_divi (a : int) (q : nat) :
  1 < q ->
  (q %| `|a|)%N ->
  `|a| < 2 * q ->
       { c : nat |
         `| a | = (c * q)%N /\ c <= 1}.
Proof.
  by apply bounded_dvdn.
Qed.

Lemma bounded_divn_alt (a : nat) (q k : nat) :
  1 < q ->
  (q %| a)%N ->
  a <= k * q ->
  { c : nat | a = (c * q)%N /\ c <= k}.
Proof.
  move=> qbig.
  exists (a %/ q)%nat.
  by rewrite divnK //  leq_divLR.
Qed.

Lemma bounded_divi_alt (a : int) (q k : nat) :
  1 < q ->
  (q %| `|a|)%N ->
  `|a| <= k * q ->
       { c : nat | `| a | = (c * q)%N /\ c <= k}.
Proof.
  apply bounded_divn_alt.
Qed.

Lemma absz_triang (a b : int) :
  `|a + b| <= `|a| + `|b|.
Proof.
  lia.
Qed.

Lemma Zp_int (p:nat) (a : int) (pbig:1<p) :
  (a %:~R : 'Z_p) = match a
                    with
                    | Posz n => inZp n
                    | Negz n => inZp (p - modn (n.+1) p)
                    end.
Proof.
  destruct a.
  - by rewrite /intmul Zp_nat.
  - rewrite /intmul.
    rewrite /intmul Zp_nat.
    rewrite /opp /= /Zp_opp /=.
    apply ord_inj => /=.
    by rewrite Zp_cast //.
Qed.

Lemma Z_q_0_dvd_abs {q : nat} (a : int) :
  1 < q ->
  a %:~R = (0 : 'Z_q) ->
  (q %| `|a|)%N.
Proof.
  move => qbig.
  rewrite Zp_int //.
  case: a => n /=.
  - move/(f_equal val) => /=.
    rewrite Zp_cast //.
    by move/eqP.
  - move/(f_equal val) => /=.
    rewrite Zp_cast //.
    rewrite modnB; try lia.
    rewrite modnn modn_mod.
    lia.
 Qed.

Lemma zliftc_add2_ex {q : nat} (a b : 'Z_q) :
  1 < q ->
  { c : nat |
    `|zliftc (a + b)%R -  ((zliftc a) + (zliftc b))%R  | = (c * q)%N /\
                                                           c <= 1}.
Proof.
  intros.
  apply bounded_divi; trivial.
  - apply Z_q_0_dvd_abs; trivial.
    rewrite rmorphD rmorphN !rmorphD /=.
    rewrite !zliftc_valid //.
    ring.
  - move: (zliftc_bound a H) => a_bound.
    move: (zliftc_bound b H) => b_bound.
    move: (zliftc_bound (a + b) H) => ab_bound.    
    move: (absz_triang (zliftc a) (zliftc b)) => triang_ab.
    move: (absz_triang (zliftc (a+b)) (- (zliftc a + zliftc b))) => triang_abc.    
    rewrite -abszN in triang_ab.
    assert (q/2 + q/2 + q/2 < 2 * q)%N.
    {
      move: (Nat.divmod_spec q 1 0 1 (le_refl _)) => /=.
      case: Nat.divmod => /= x y.
      rewrite !Nat.add_0_r.
      move=> [qeq ubound]; subst.
      destruct y; lia.
    }
    lia.
Qed.

Lemma zliftc_mul2 {q : nat} (a b : 'Z_q) :
  1 < q ->
  `|(zliftc (a * b) - (zliftc a) * (zliftc b))%R  | <= (q/2 * (1 + q/2))%N.
Proof.
  intros.
  move: (zliftc_bound a H) => a_bound.
  move: (zliftc_bound b H) => b_bound.
  move: (zliftc_bound (a * b) H) => ab_bound.
  move: (absz_triang (zliftc (a*b)) (- (zliftc a * zliftc b))) => triang.
  rewrite abszN in triang.
  assert (`|zliftc a * zliftc b| <= (q/2) * (q/2)).
  {
    rewrite abszM.
    by apply leq_mul.
  }
  lia.
  Qed.

Lemma zliftc_mul2_ex {q : nat} (a b : 'Z_q) :
  1 < q ->
  { c : nat |
    `|zliftc (a * b)%R -  ((zliftc a) * (zliftc b))%R  | = (c * q)%N /\
                                                           c <= q/2}.
Proof.
  intros.
  apply bounded_divi_alt; trivial.
  - apply Z_q_0_dvd_abs; trivial.
    rewrite rmorphD rmorphN rmorphM /=.
    rewrite !zliftc_valid //.
    ring.
  - generalize (zliftc_mul2 a b H); intros.
    assert ((q / 2) * (1 + q / 2) <= (q/2) * q).
    {
       rewrite -Nat.div2_div leq_pmul2l.
      - generalize (Nat.lt_div2 q); lia.
      - generalize (div2_not_R0 q); lia.
    }
    lia.
Qed.

Definition zlift {q : nat} (a : {poly 'Z_q}) : {poly int} :=
  map_poly zliftc a.

Lemma zliftc0 (q : nat) :
  zliftc (0 : 'Z_q) = 0.
Proof.
  by rewrite /zliftc.
Qed.  

Lemma zlift0 {q : nat} (a : {poly 'Z_q}) :
  a = 0 -> 
  zlift a = 0.
Proof.
  intros.
  rewrite /zlift /zliftc H.
  apply map_poly0.
Qed.  

Lemma zlift0_alt {q : nat} :
  zlift (0 : {poly 'Z_q}) = 0.
Proof.
  rewrite /zlift /zliftc.
  apply map_poly0.
Qed.  


Definition icoef_maxnorm (p : {poly int}):nat := \max_(j < seq.size p) `|p`_ j|.

Lemma zlift_add2_ex {q : nat} (a b : {poly 'Z_q}) :
  (1 < q) ->
  { c : {poly int} |
    zlift  (a + b) = zlift a + zlift b + c /\
      icoef_maxnorm c <= q}.
Proof.
  exists (zlift (a + b) - (zlift a + zlift b)).
  split.
  - ring.
  - rewrite /icoef_maxnorm /zlift.
    apply /bigmax_leqP => i _.
    rewrite !(coefD,coefN).
    rewrite !coef_map_id0; try apply zliftc0.
    rewrite !coefD; try apply zlift0_alt.
    by apply zliftc_add2.
Qed.

Definition zlift_add2_perturb {q : nat} (qbig:(1 < q)) (a b : {poly 'Z_q}) :  {poly int}
  := sval (zlift_add2_ex a b qbig).

Lemma zlift_add2_eq {q : nat} (qbig:(1 < q)) (a b : {poly 'Z_q})  
  : zlift (a + b) = zlift a + zlift b + zlift_add2_perturb qbig a b.
Proof.
  rewrite /zlift_add2_perturb.
  case: (zlift_add2_perturb qbig a b).
  case: zlift_add2_ex; intros; simpl.
  tauto.
Qed.

Lemma zlift_add2_perturb_small {q : nat} (qbig:(1 < q)) (a b : {poly 'Z_q})  
  : icoef_maxnorm (zlift_add2_perturb qbig a b) <= q.
Proof.
  rewrite /zlift_add2_perturb.
  case: (zlift_add2_perturb qbig a b).
  case: zlift_add2_ex; intros; simpl.
  tauto.
Qed.

Definition upi (c:R) : int := ssrZ.int_of_Z (up c).

(* 0 <= rand < 1 *)
Definition ran_round (x rand : R) : int :=
  let hi := upi x in
  if (Order.lt (hi%:~R - x) rand)%R then hi else (hi - 1).

Definition nearest_round (x : R) : int := ran_round x (1/2)%R.

Definition nearest_round_int (n d : int) : int := nearest_round ((n %:~R)/(d %:~R))%R.



Lemma IZRE (n : Z) : IZR n = (ssrZ.int_of_Z n)%:~R.
Proof.
  destruct n.
  - by rewrite /intmul /= /IZR R00.
  - by rewrite /IZR -INR_IPR INRE /ssrZ.int_of_Z /intmul.
  - rewrite /IZR -INR_IPR INRE /ssrZ.int_of_Z /intmul /opp /=.
    f_equal; f_equal.
    lia.
Qed.    

Lemma IZREb (n : int) :  n%:~R = IZR (ssrZ.Z_of_int n).
Proof.
  by rewrite -{1}(ssrZ.Z_of_intK n) -IZRE.
Qed.

Lemma up_int_add (n : Z) (c : R) :
  up (Rplus (IZR n) c) = Zplus n (up c).
Proof.
  symmetry.
  destruct (archimed c).
  apply tech_up; rewrite plus_IZR; coq_lra.
Qed.

Lemma upi_intl (n : int) (c : R) :
  upi ((n%:~R) + c) = n + upi c.
Proof.
  rewrite /upi !IZREb up_int_add.
  lia.
Qed.

Lemma upi0 :
  upi 0 = 1.
Proof.
  rewrite /upi -(tech_up 0 1); try coq_lra.
  lia.
Qed.

Lemma nearest_round_int0 (d : int) :
  nearest_round_int 0 d = 0.
Proof.
  rewrite /nearest_round_int /nearest_round /ran_round.
  rewrite mul0r upi0 oppr0 addr0 addrN.
  rewrite /intmul /=.
  rewrite ssrnum.Num.Theory.ltr_pdivlMr; last by lra.
  by rewrite mul1r /natmul/= ssrnum.Num.Theory.gtrDl ssrnum.Num.Theory.ltr10.    
Qed.

Lemma nearest_round_int_add (n1 : int) (c : R) :
  nearest_round (n1 %:~R + c)%R = n1 + nearest_round c.
Proof.
  rewrite /nearest_round /ran_round.
  have ->: (upi (n1%:~R + c))%:~R - (n1%:~R + c)%R = ((upi c)%:~R - c).
  {
    rewrite upi_intl; lra.
  }
  case: Order.TotalTheory.ltP => _ ; by rewrite upi_intl; lra.
Qed.

Lemma nearest_round_int_mul_add (n1 n2 d : int) :
  d <> 0 ->
  nearest_round_int (n1 * d + n2) d = n1 + nearest_round_int n2 d.
Proof.
  intros.
  rewrite /nearest_round_int -nearest_round_int_add.
  rewrite intrD intrM mulrDl.
  rewrite -mulrA divff.
  - f_equal; lra.
  - rewrite intr_eq0.
    by apply/eqP.
Qed.

Lemma nearest_round_int_mul_add_r (n1 n2 d : int) :
  d <> 0 ->
  nearest_round_int (n1 + d * n2) d = nearest_round_int n1 d + n2.
Proof.
  intros.
  rewrite mulrC addrC nearest_round_int_mul_add //.
  lia.
Qed.

Lemma up_add2' (r1 r2 : R) :
  (up(r1 + r2) = Z.add (up r1) (up r2) \/ up(r1 + r2) = Z.sub (Z.add (up r1) (up r2)) 1)%Z.
Proof.
  destruct (archimed r1).
  destruct (archimed r2).
  destruct (archimed (r1 + r2)).  
  case: (boolP (Rleb ((IZR (up r1) + IZR (up r2)) - (r1 + r2)) 1)).
  - intros.
    left.
    move /RlebP in p.
    by rewrite (tech_up (r1 + r2) (up r1 + up r2)) // plus_IZR; coq_lra.
  - intros.
    right.
    move /RlebP in i.
    by rewrite (tech_up (r1 + r2) (up r1 + up r2 - 1)) // !plus_IZR opp_IZR; coq_lra.
Qed.

Lemma up_add2 (r1 r2 : R) :
  Z.abs_nat (Z.sub (up (r1 + r2)) (Z.add (up r1) (up r2))) <= 1.
Proof.
  destruct (up_add2' r1 r2); rewrite H; lia.
Qed.


Lemma int_of_Z_abs x : `|int_of_Z x| = Z.abs_nat x.
Proof.
  rewrite /int_of_Z /absz /Z.abs_nat.
  destruct x; trivial.
  lia.
Qed.  

Lemma upi_add2' (n1 n2 : R) :
  (upi (n1 + n2) = (upi n1 + upi n2))%R \/
    (upi (n1 + n2) = (upi n1 + upi n2) -1)%R.
Proof.
  rewrite /upi.
  destruct (up_add2' n1 n2).
  - left.
    by rewrite H raddfD /=.
  - right.
    rewrite H.
    rewrite -Z.add_opp_r !raddfD /=.
    lra.
Qed.

Lemma upi_add2 (n1 n2 : R) :
   `|upi (n1 + n2) - (upi n1 + upi n2)%R| <= 1.
Proof.
  rewrite /upi.
  rewrite (_:
            ssrZ.int_of_Z (up (n1 + n2)) - (ssrZ.int_of_Z (up n1) + ssrZ.int_of_Z (up n2))%R =
              ssrZ.int_of_Z (Z.sub (up (n1 + n2)) (Z.add (up n1) (up n2)))%Z).
  - rewrite int_of_Z_abs.
    apply up_add2.
  - rewrite -Z.add_opp_r !raddfD /= raddfN /= raddfD /=.
    lra.
Qed.

Lemma ran_round_add2 (n1 n2 cutoff : R) :
  ((0 : R) < cutoff)%O -> 
  (cutoff < (1 : R))%O -> 
  let sum := ran_round n1 cutoff + ran_round n2 cutoff  in
  `|ran_round (n1 + n2)%R cutoff - sum| <= 1.
Proof.
  move=> cutoff_big cutoff_small.
  rewrite /ran_round.
  case: Order.TotalTheory.ltP=>lt1 ; case: Order.TotalTheory.ltP => lt2 ; case: Order.TotalTheory.ltP => lt3
                                                                                                      ; try (destruct (upi_add2' n1 n2); rewrite H; try lia; rewrite H raddfD /= in lt1; lra).
Qed.

Lemma nearest_round_add2 (n1 n2 : R) :
  let sum := nearest_round n1 + nearest_round n2 in
  `|nearest_round (n1 + n2) - sum| <= 1.
Proof.
  rewrite /nearest_round.
  apply ran_round_add2; lra.
Qed.

Lemma nearest_round_int_add2 (n1 n2 d : int) :
  d <> 0 ->
  let sum := nearest_round_int n1 d + nearest_round_int n2 d in
  `|nearest_round_int (n1 + n2) d - sum| <= 1.
Proof.
  move=> dn0.
  rewrite /= /nearest_round_int.
  rewrite (_:((n1 + n2)%:~R / d%:~R)%R = ((n1%:~R / d%:~R) + (n2%:~R / d%:~R))%R).
  - apply nearest_round_add2.
  - ring.
Qed.

Lemma upi_bound (r : R) :
  let diff := (upi r)%:~R - r in 
  Rlt 0%R diff /\ Rle diff 1%R.
Proof.
  rewrite /upi -IZRE.
  apply for_base_fp.
Qed.

Lemma upi_bound_O (r : R) :
  let diff := (upi r)%:~R - r in 
  ((0 : R) < diff)%O /\ (diff <= 1%R)%O.
Proof.
  destruct (upi_bound r).
  move /RltP in H.
  by move /RleP in H0.
Qed.

Lemma int_to_R_lt :
  {mono (intmul (1 : R)) : x y / (x < y)%O}.
Proof.
  move=> x y.
  apply ltr_int.
Qed.

Lemma int_to_R_le :
  {mono (intr: int -> R) : x y / (x <= y)%O}.
Proof.
  move => x y.
  apply ler_int.
Qed.

Lemma upi_nat_mul_bound_R (r : R) (n : nat) :
  (((upi r)%:~R *+n - r*+n) <= n%:R)%O.
Proof.
  destruct (upi_bound_O r).
  assert ((0 : R) <= n%:R)%O.
  {
    by rewrite (ler_int _ 0 n).
  }
  apply (ssrnum.Num.Theory.ler_wpM2r H1) in H0.
  rewrite mul1r mulrBl in H0.
  by replace  ((upi r)%:~R *+ n - r *+ n ) with
    ((upi r)%:~R * n%:R - r * n%:R) by ring.
Qed.

Lemma Rabs_left_O (r : R) :
  (r <= 0)%O -> Rabs r = -r.
Proof.
  intros.
  move /RleP in H.
  rewrite /opp /=.
  rewrite /zero /= in H.
  case: (boolP (r == 0)); intros.
  - rewrite (eqP p) Rabs_R0 /zero /=.
    coq_lra.
  - move /eqP in i.
    apply Rabs_left.
    rewrite /zero /= in i.
    coq_lra.
Qed.

Lemma nearest_round_bound_O (r : R) :
  let diff := (nearest_round r)%:~R - r in   
  (Rabs diff <= 1/2)%O.
Proof.
  rewrite /nearest_round /ran_round.
  destruct (upi_bound_O r).
  case: (boolP (Order.lt _ _)); intros.
  - rewrite Rabs_right.
    + by apply Order.POrderTheory.ltW.
    + apply Rle_ge.
      left.
      apply /RltP.
      by rewrite /zero /= in H.
  - rewrite Order.TotalTheory.ltNge in i.
    apply negbNE in i.
    rewrite Rabs_left_O; lra.
Qed.

Lemma nearest_round_bound_O' (r : R) :
  let diff := (nearest_round r)%:~R - r in   
  Rabs diff <> 1/2 ->
  (Rabs diff < 1/2)%O.
Proof.
  generalize (nearest_round_bound_O r); intros.
  rewrite Order.POrderTheory.lt_neqAle.
  unfold diff in *.
  move /eqP in H0.
  by apply /andP.
Qed.

Lemma Rabs_n (r : R) (n : nat) :
  (Rabs r) *+n = Rabs (r *+ n).
Proof.
  rewrite -mulr_natr -(mulr_natr r n) RnormM.
  rewrite /mul /=.
  f_equal.
  rewrite Rabs_right //.
  apply Rle_ge.
  apply /RleP.
  replace (IZR Z0) with (0%:R : R).
  - rewrite  ssrnum.Num.Theory.ler_nat.
    lia.
  - by rewrite mulr0n /zero /=.
 Qed.

Lemma nearest_round_nat_mul_bound_R (r : R) (n : nat) :
 (Rabs (add ((nearest_round r)%:~R *+n) (opp r*+n)) <= (1/2)*+n)%O.
Proof.
  generalize (nearest_round_bound_O r); intros.
  apply (ssrnum.Num.Theory.ler_wMn2r (R := R_numDomainType) n) in H.
  apply /RleP.
  move /RleP in H.
  eapply Rle_trans; [|apply H].
  right.
  rewrite Rabs_n.
  f_equal.
  ring.
Qed.

Lemma nearest_round_nat_mul_bound_R'_S (r : R) (n : nat) :
  Rabs ((nearest_round r)%:~R - r) <> 1/2 ->
 (Rabs (add ((nearest_round r)%:~R *+n.+1) (opp r*+n.+1)) < (1/2)*+n.+1)%O.
Proof.
  intros.
  generalize (nearest_round_bound_O' r H); intros.
  apply (ssrnum.Num.Theory.ltr_wMn2r (R := R_numDomainType) n.+1) in H0.
  apply /RltP.
  assert (0 < n.+1) by lia.
  rewrite H1 in H0.
  move /RltP in H0.
  eapply Rle_lt_trans; [|apply H0].
  right.
  rewrite Rabs_n.
  f_equal.
  ring.
Qed.

Lemma upi_nat_mul_bound_R0_lt (r : R) (n : nat) :
  ((0 : R) < ((upi r)%:~R *+n.+1 - r*+n.+1))%O.
Proof.
  destruct (upi_bound_O r).
  assert (0 < n.+1) by lia.
  apply (ssrnum.Num.Theory.ltr_wpMn2r H1 (R := R_numDomainType)) in H.
  rewrite mul0rn in H.
  by replace  ((upi r)%:~R *+ n.+1 - r *+ n.+1 ) with
    (((upi r)%:~R - r) *+ n.+1) by ring.
Qed.

Lemma upi_nat_mul_bound_R0_lt_alt (r : R) (n : nat) :
  (r *+ n.+1 < (upi r)%:~R *+n.+1)%O.
Proof.
  generalize (upi_nat_mul_bound_R0_lt r n); intros.
  lra.
Qed.

Lemma upi_nat_mul_bound_R0_lt_alt_alt (r : R) (n : nat) :
  (r *+ n.+1 < ((upi r)*+n.+1)%:~R)%O.
Proof.
  generalize (upi_nat_mul_bound_R0_lt_alt r n); intros.
  by replace ((upi r *+ n.+1)%:~R)%R with ((((upi r)%:~R) : R) *+ n.+1) by ring.
Qed.

Lemma up_lt_le (r : R) (i : Z) :
  (Rlt r  (IZR i)) ->
  Z.le (up r) i.
Proof.
  intros.
  destruct (archimed r); intros.
  assert (Rle (IZR (up r) - 1) r) by coq_lra.
  assert (IZR (up r) - 1 = IZR ((up r) - 1)).
  {
    rewrite /opp /add /one /=.
    rewrite minus_IZR.
    coq_lra.
  }
  assert (~(Z.lt i (up r))).
  {
    intros ?.
    assert (Z.le i ((up r) - 1)) by lia.
    assert (Rle (IZR i) (IZR ((up r) -1))).
    {
      by apply IZR_le.
    }
    rewrite -H3 in H6.
    assert (Rle (IZR i) r).
    {
      eapply Rle_trans.
      apply H6.
      apply H2.
    }
    coq_lra.
  }
  lia.
Qed.

Lemma upi_lt_le (r : R) (i : int) :
  (r < i%:~R)%O ->
  (upi r <= i)%O.
Proof.
  intros.
  generalize (up_lt_le r (Z_of_int i)); intros.
  rewrite -IZREb in H0.
  move /RltP in H.
  specialize (H0 H).
  rewrite /upi.
  lia.
Qed.

Lemma upi_nat_mul_bound_R0_le (r : R) (n : nat) :
  ((0 : R) <= ((upi r)%:~R *+n - r*+n))%O.
Proof.
  destruct n.
  - lra.
  - apply Order.POrderTheory.ltW.
    apply upi_nat_mul_bound_R0_lt.
Qed.

Lemma upi_nat_mul_le (r : R) (n : nat) :
  (upi (r *+ n.+1) <= upi(r)*+n.+1)%O.
Proof.
  apply upi_lt_le.
  apply upi_nat_mul_bound_R0_lt_alt_alt.
Qed.  

Definition upiR (r: R) : R := (upi r) %:~R.

Lemma eq_rel2 {A B:Type} {RR:A->B->bool} {a: A} {b:B} {c:A} {d:B} :
  RR a b ->
  a = c ->
  b = d ->
  RR c d.
Proof.
  congruence.
Qed.

Lemma upi_nat_mul' (r : R) (n : nat) :
  (upi(r)*+n.+1 - upi (r *+ n.+1) < n.+1%:R)%O.
Proof.
  destruct (upi_bound_O (r *+ n.+1)).
  generalize (upi_nat_mul_bound_R r n.+1); intros.
  assert ((upiR r) *+ n.+1 - (upiR (r*+n.+1)) < (n.+1%:R))%O.
  {
    replace  ((upiR r) *+ n.+1 - upiR (r *+ n.+1)) with
      ( (upiR r) *+ n.+1 - r*+n.+1 - (upiR (r *+ n.+1) - r*+n.+1)) by ring.
    eapply Order.POrderTheory.lt_le_trans; [| apply H1].
    rewrite /upiR.
    
    have: (forall (a b : R), ((0 : R) < b)%O -> (a - b < a)%O) by (intros; lra).
    by apply.
  }
  rewrite /upiR in H2.
  rewrite -int_to_R_lt.
  apply (eq_rel2 H2); ring.
Qed.

Lemma upi_nat_mul'' (r : R) (n : nat) :
  ((0:int) <= upi(r)*+n.+1 - upi (r *+ n.+1) < n.+1%:R)%O.
Proof.
  apply /andP.
  split.
  - generalize (upi_nat_mul_le r n); intros.
    lia.
  - apply upi_nat_mul'.
Qed.

Lemma upi_nat_mul (r : R) (n : nat) :
  (upi(r)*+n - upi (r *+ n) < n%:R)%O.
Proof.
  destruct n.
  - by rewrite !mulr0n upi0 add0r.
  - apply upi_nat_mul'.
Qed.

Lemma upi_nat_mul_pos (r : R) (n : nat) :
  ((0 : int) <= upi(r)*+n.+1 - upi (r *+ n.+1))%O.
Proof.
  generalize (upi_nat_mul_le r n); intros.
  lia.
Qed.

Lemma upi_nat_mul_abs_S (r : R) (n : nat) :
  `|upi (r *+ n.+1) - upi(r)*+n.+1| < n.+1.
Proof.
  rewrite distnC.
  assert (Posz `|upi r *+ n.+1 - upi (r *+ n.+1)| < Posz n.+1)%O. 
  {
    rewrite gez0_abs; [| apply (upi_nat_mul_pos r n)].
    generalize (upi_nat_mul' r n); intros.
    lia.
  }
  lia.
Qed.

Lemma upi_nat_mul_abs (r : R) (n : nat) :
  `|upi (r *+ n) - upi(r)*+n| <= n.+1.
Proof.
  destruct n.
  - by rewrite !mulr0n upi0 addr0.
  - generalize (upi_nat_mul_abs_S r n).
    lia.
Qed.

Lemma Rabs_opp_sym (x y : R) :
  Rabs (add x (opp y)) = Rabs (add y (opp x)).
Proof.
  generalize (Rabs_minus_sym x y); intros.
  rewrite /add /opp /=.
  by rewrite /Rminus in H.
Qed.

Lemma Rplus_add (x y : R) :
  Rplus x y = add x y.
Proof.
  by rewrite /add /=.
Qed.

Lemma Ropp_opp(x : R) :
  Ropp x = opp x.
Proof.
  by rewrite /opp /=.
Qed.

Lemma Rmult_mul (x y : R) :
  Rmult x y = mul x y.
Proof.
  by rewrite /mul /=.
Qed.

Lemma Rabs_absz (j : int) :
  Rabs (j %:~R) = (`|j|%:~R).
Proof.
  rewrite /absz.
  destruct j.
  - rewrite Rabs_right //.
    apply Rle_ge.
    apply /RleP.
    replace (IZR Z0) with ((0 %:~R):R).
    + rewrite int_to_R_le; lia.
    + by rewrite /zero /=.
  - rewrite NegzE Rabs_left.
    + rewrite Ropp_opp.
      by rewrite mulrNz opprK.
    + apply /RltP.
      replace (IZR Z0) with ((0 %:~R):R).
      * rewrite int_to_R_lt; lia.
      * by rewrite /zero /=.
Qed.

Lemma half_lt (j : int) (n : nat) :
  (Posz (n/2)%N < j)%O ->
  (Posz n < 2 * j)%O.
Proof.
  intros.
  generalize (Nat.div_mod_eq n 2); intros.
  case: (boolP (n mod 2 == 0%N)); intros; try lia.
  generalize (Nat.mod_upper_bound n 2); intros.
  lia.
Qed.

Lemma half_int_to_R_le (j : int) (n : nat):
  ((j %:~R : R) <= (1/2 : R) *+ n)%O ->
  (j <= (n / 2)%N)%O.                           
Proof.
  intros.
  case: (boolP (Order.le _ _)); intros; trivial.
  rewrite -Order.TotalTheory.ltNge in i.
  assert ((n : int) < 2*j)%O.
  {
    by apply half_lt.
  }
  rewrite -(@ltr_int R_numDomainType) in H0.
  assert ( (n%:~R : R) / 2 < j%:~R)%O by lra.
  rewrite -(@ltr_int R_numDomainType) in i.
  assert ( (1 / 2 : R) *+ n < j%:~R)%O.
  {
    assert ((1 / 2 : R) *+ n = (n%:~R : R) / 2) by ring.
    by rewrite H2.
  }
  lra.
Qed.

(*
Lemma half_int_to_R_lt (j : int) (n : nat):
  ((j %:~R : R) < (1/2 : R) *+ n)%O ->
  (j < (n / 2)%N)%O.                           
Proof.
  intros.
  case: (boolP (Order.lt _ _)); intros; trivial.
  rewrite -Order.TotalTheory.leNgt in i.
  assert ((n : int) <= 2*j)%O.
  {
    by apply half_le.
  }
  rewrite -(@ltr_int R_numDomainType) in H0.
  assert ( (n%:~R : R) / 2 < j%:~R)%O by lra.
  rewrite -(@ltr_int R_numDomainType) in i.
  assert ( (1 / 2 : R) *+ n < j%:~R)%O.
  {
    assert ((1 / 2 : R) *+ n = (n%:~R : R) / 2) by ring.
    by rewrite H2.
  }
  lra.
Qed.
*)

Lemma Rabs_absz_half (j : int) (n : nat) :
  (Rabs (j %:~R) <= (1/2 : R) *+ n)%O ->
    (`|j| <= (n/2)%N)%O.
Proof.
  intros.
  rewrite Rabs_absz in H.
  apply half_int_to_R_le in H.
  apply H.
Qed.

Lemma nearest_round_mul_abs_nat (r : R) (n : nat) :
  `|nearest_round (r *+ n) - nearest_round(r)*+n| <= (n.+1)/2.
Proof.
  generalize (nearest_round_nat_mul_bound_R r n); intros.
  generalize (nearest_round_bound_O (r *+ n)); intros.
  simpl in H0.
  rewrite Rabs_opp_sym in H0.
  generalize (ssrnum.Num.Theory.lerD H H0); intros.
  generalize (Rabs_triang
                ((nearest_round r)%:~R *+ n + - r *+ n)%R
                (r *+ n - (nearest_round (r *+ n))%:~R)%R ); intros.
  move /RleP in H1.
  generalize (Rle_trans _ _ _ H2 H1); intros.
  replace  (Rplus ((nearest_round r)%:~R *+ n + - r *+ n)%R
              (r *+ n - (nearest_round (r *+ n))%:~R)%R) with
    ((((nearest_round r)%:~R : R)*+ n) -
       (nearest_round (r *+ n))%:~R)%R in H3.
  - rewrite distnC.
    rewrite -mulrSr in H3.
    assert
      (((nearest_round r)%:~R *+ n -
          (nearest_round (r *+ n))%:~R)%R =
      ((nearest_round r *+ n - nearest_round (r *+ n))%:~R : R)) by ring.
    rewrite H4 in H3.
    move /RleP in H3.
    apply Rabs_absz_half in H3.
    apply H3.
  - rewrite Rplus_add.
    ring.
Qed.


Lemma nearest_round_0 :
  nearest_round 0 = 0.
Proof.
  rewrite /nearest_round /ran_round upi0 oppr0 addr0.
  replace  (((1%:~R : R )< 1 / 2)%O) with false by lra.
  lia.
Qed.

Lemma nearest_round_int_val (n : int) :
  nearest_round (n %:~R) = n.
Proof.
  rewrite /nearest_round /ran_round.
  generalize (upi_intl n 0); intros.
  rewrite Rplus_add addr0 upi0 in H.
  rewrite H intrD addrC addrA addNr add0r.
  replace  ((1%:~R : R) < 1 / 2)%O with false by lra.
  lia.
Qed.

Lemma nearest_round_half (r : R) :
  Rabs ((nearest_round r)%:~R - r) = 1 / 2  ->
  forall (n : nat),
    odd n ->
    (Rabs ((nearest_round (r *+ n.+1))%:~R - r *+ n.+1)%R =
       1 / 2).
Proof.  
  intros.
  Admitted.

Lemma nearest_round_not_half (r : R) :
  Rabs ((nearest_round r)%:~R - r) <> 1 / 2  ->
  forall (n : nat),
    (Rabs ((nearest_round (r *+ n.+1))%:~R - r *+ n.+1)%R <>
       1 / 2).
Proof.
  intros.
Admitted.

Lemma nearest_round_mul_abs_nat_half (r : R) (n : nat) :
  (upi r)%:~R - r = 1 / 2 ->
  `|nearest_round (r *+ n) - nearest_round(r)*+n| <= n/2.
Proof.  
  Admitted.

Lemma nearest_round_mul_abs_nat_not_half (r : R) (n : nat) :
  Rabs ((nearest_round r)%:~R - r) <> 1 / 2  ->
  `|nearest_round (r *+ n.+1) - nearest_round(r)*+n.+1| < n.+2/2.
Proof.
  intros.
  generalize (nearest_round_nat_mul_bound_R'_S r n H); intros.
  assert  (Rabs ((nearest_round (r *+ n.+1))%:~R - r *+ n.+1)%R <>
       1 / 2).
  {
    admit.
  }
  generalize (nearest_round_bound_O' (r *+ n.+1) H1); intros.
  rewrite Rabs_opp_sym in H2.
  generalize (ssrnum.Num.Theory.ltrD H0 H2); intros.  
  generalize (Rabs_triang
                ((nearest_round r)%:~R *+ n.+1 + - r *+ n.+1)%R
                (r *+ n.+1 - (nearest_round (r *+ n.+1))%:~R)%R ); intros.
  move /RltP in H3.
  generalize (Rle_lt_trans _ _ _ H4 H3); intros.
  rewrite Rplus_add in H5.
  rewrite -addrA (addrA _ (r *+ n.+1) _) in H5.
  replace (- r *+ n.+1 + r *+ n.+1) with (0:R) in H5 by ring.
  rewrite add0r -mulrSr in H5.
  rewrite distnC.
  assert
    (((nearest_round r)%:~R *+ n.+1 -
        (nearest_round (r *+ n.+1))%:~R)%R =
       ((nearest_round r *+ n.+1 - nearest_round (r *+ n.+1))%:~R : R)) by ring.
  rewrite H6 in H5.
  move /RltP in H5.
(*
  apply Rabs_absz_half in H5.
    apply H3.
 *)
  Admitted.


Lemma nearest_round_mul_abs_nat_0 (r : R) (n : nat) :
  `|nearest_round (r *+ 0) - nearest_round(r)*+0| = 0%N.
Proof.
  by rewrite mulr0n nearest_round_0 mulr0n oppr0 addr0 /=.
Qed.

Lemma nearest_round_mul_abs_nat_opp (r : R) (n : nat) :
 `|nearest_round r *+ n + nearest_round (r *- n)| <=
  n.+1 / 2.
Proof.
  replace (r *-n) with ((opp r) *+ n) by ring.
  generalize (nearest_round_nat_mul_bound_R r n); intros.
  generalize (nearest_round_bound_O ((opp r) *+ n)); intros.
  simpl in H0.
  replace (opp (natmul (opp r) n)) with (natmul r n) in H0 by ring.
  generalize (ssrnum.Num.Theory.lerD H H0); intros.
  generalize (Rabs_triang
                ((nearest_round r)%:~R *+ n + - r *+ n)%R
                 ((nearest_round (- r *+ n))%:~R + r *+ n)%R); intros.
  move /RleP in H1.
  generalize (Rle_trans _ _ _ H2 H1); intros.
  rewrite Rplus_add in H3.
  rewrite -addrA (addrC (-r *+ n) _) -addrA in H3.
  replace (r *+ n + (-r) *+n) with (0 : R) in H3 by ring.
  rewrite addr0 -mulrSr in H3.
  assert
    ((((nearest_round r)%:~R *+ n +
            (nearest_round (- r *+ n))%:~R)%R) =
       ((((nearest_round r) *+ n +
              (nearest_round (- r *+ n)))%:~R) : R))  by ring.
  rewrite H4 in H3.
  move /RleP in H3.
  apply Rabs_absz_half in H3.
  apply H3.
Qed.

(*
 r = IZR (Int_part r) + frac_part r.
 0 <= frac_part r < 1.
*)

Lemma up_opp_Z (r : R) :
  IZR (up r) = Rplus r 1 ->
  up (-r) = Zplus (- (up r)) (Zpos 2).
Proof.
  intros.
  symmetry.
  apply tech_up.
  - rewrite plus_IZR opp_IZR H.
    coq_lra.
  - rewrite plus_IZR opp_IZR H.
    coq_lra.
Qed.

Lemma up_opp_nZ (r : R) :
  IZR (up r) <> Rplus r 1 -> 
  up (-r) = Zplus (- (up r)) (Zpos 1).
Proof.
  intros.
  symmetry.
  destruct (archimed r).
  apply tech_up.
  - rewrite plus_IZR opp_IZR.
    coq_lra.
  - rewrite plus_IZR opp_IZR.
    coq_lra.
Qed.

Lemma upi_opp_int (r : R) :
  (upi r)%:~R = r + 1 ->
  upi (opp r) = - (upi r) + 2.
Proof.
  intros.
  rewrite /upi up_opp_Z.
  - lia.
  - by rewrite -IZRE /add /one /= in H.
Qed.

Lemma upi_opp_nint (r : R) :
  (upi r)%:~R <> r + 1 ->
  upi (opp r) = - (upi r) + 1.
Proof.
  intros.
  rewrite /upi up_opp_nZ.
  - lia.
  - by rewrite -IZRE /add /one /= in H.
Qed.

Lemma nearest_round_opp_not_half (r : R) :
  (upi r)%:~R - r <> 1/2 ->
  nearest_round (opp r) = - nearest_round r.
Proof.
  rewrite /nearest_round /ran_round.
  case: (boolP ((upi r)%:~R == r + 1)); intros.
  - move /eqP in p.
    rewrite (upi_opp_int r p) opprK rmorphD rmorphN /= p.
    case: (boolP (Order.lt _ _)); intros.
    + by assert false by lra.
    + case: (boolP (Order.lt _ _)); intros.
      * by assert false by lra.
      * ring.
  - move /eqP in i.
    rewrite (upi_opp_nint r i) opprK rmorphD rmorphN /=.
    case: (boolP (Order.lt _ _)); intros.
    + case: (boolP (Order.lt _ _)); intros.
      * by assert false by lra.
      * ring.
    + case: (boolP (Order.lt _ _)); intros.
      * ring.
      * by assert false by lra.
Qed.

Lemma nearest_round_opp_half (r : R) :
  (upi r)%:~R - r = 1/2 ->
  nearest_round (-r) = - nearest_round r - 1.
Proof.
  rewrite /nearest_round /ran_round.
  intros.
  assert( (upi r)%:~R <> r + 1 ) by lra.
  rewrite (upi_opp_nint r H0) rmorphD rmorphN /= opprK.
  case : (boolP (Order.lt _ _)); intros.
  - by assert false by lra.
  - case : (boolP (Order.lt _ _)); intros.
    + by assert false by lra.
    + ring.
Qed.

Lemma upi_mul_abs (r : R) (n : int) :
  `|upi (r *~ n) - (upi r) *~n| <= `|n|+1.
Proof.
  destruct n; simpl.
  - rewrite -!pmulrn.
    generalize (upi_nat_mul_abs r n); intros.
    lia.
  - rewrite distnC /intmul /=.
    generalize (upi_nat_mul_abs_S r n); intros.
    rewrite distnC in H.
    case: (boolP ((upi (r *+ n.+1))%:~R == (r*+n.+1)+1)); intros.
    + rewrite (upi_opp_int _ (eqP p)) opprD opprK addrC distnC.
      rewrite opprB (addrC 2 _) addrA.
      generalize (absz_triang (upi r *+ n.+1 - upi (r *+ n.+1)) 2); intros.
      lia.
    + move /eqP in i.
      rewrite (upi_opp_nint _ i) opprD opprK addrC distnC.
      rewrite opprB (addrC 1 _) addrA.
      generalize (absz_triang (upi r *+ n.+1 - upi (r *+ n.+1)) 1); intros.      
      lia.
Qed.

Lemma upi_mul_abs_alt (r : R) (n : int) :
  `|(upi (mul r n%:~R) - (upi r) * n)%Z| <= `|n|+1.
Proof.
  generalize (upi_mul_abs r n); intros.
  replace (upi (mul r n%:~R) - upi r * n)%R with
    (upi (r *~ n) - upi r *~ n); trivial.
  f_equal.
  - f_equal; lra.
  - f_equal; f_equal; lia.
Qed.

Lemma nearest_round_mul_abs (r : R) (n : int) :
  `|nearest_round (r *~ n) - nearest_round(r)*~n| <= (`|n|+1)/2.
Proof.
  destruct n.
  - rewrite -!pmulrn.
    generalize (nearest_round_mul_abs_nat r n); intros.
    replace (`|n| + 1)%N with (n.+1) by lia.
    lia.
  - rewrite distnC /intmul NegzE.
    replace (`|-(Posz n.+1)|+1)%N with (n.+2) by lia.
    rewrite -opprD abszN.
    apply nearest_round_mul_abs_nat_opp.
Qed.
    
Lemma nearest_round_int_mul (n1 n2 d : int) :
  d <> 0 ->
  (`|(nearest_round_int (n1 * n2) d - nearest_round_int n1 d * n2)%R|) <= (`|n2| + 1)/2.
Proof.
  rewrite /nearest_round_int intrM.
  rewrite (_: (n1%:~R * n2%:~R / d%:~R) = ((n1%:~R / d%:~R)%R * n2%:~R )); last by lra.
  move: {n1} (((n1%:~R / d%:~R)%R)) => n1 _ {d}.
  replace (n1 * n2%:~R) with (n1*~n2) by ring.
  replace (nearest_round n1 * n2) with (nearest_round n1 *~ n2).
  apply nearest_round_mul_abs.
  destruct n2; simpl; ring.
Qed.

Lemma nearest_round_int_add2_ex (n1 n2 d : int) : 
  d <> 0 ->
  let sum := nearest_round_int n1 d + nearest_round_int n2 d in
  { n3 : int |
    nearest_round_int (n1 + n2) d = sum + n3 /\
      `|n3| <= 1}.
Proof.
  intros.
  exists (nearest_round_int (n1 + n2) d - sum).
  split; try lia.
  by apply nearest_round_int_add2.
Qed.

Lemma nearest_round_int_mul_ex (n1 n2 d : int) : 
  d <> 0 ->
  { n3 : int |
    nearest_round_int (n1 * n2) d = nearest_round_int n1 d * n2 + n3 /\
      `|n3| <= (`|n2|+1)/2}.
Proof.
  intros.
  exists (nearest_round_int (n1 * n2) d - nearest_round_int n1 d * n2).
  split; try lia.
  by apply nearest_round_int_mul.
Qed.

Definition div_round (a : {poly int}) (d : int) : {poly int} :=
  map_poly (fun c => nearest_round_int c d) a.

Lemma div_round0 (den : int) :
  div_round (0 : {poly int}) den = 0.
Proof.
  rewrite /div_round.
  apply map_poly0.
Qed.

Lemma nth_map_default:
  forall [T1 : Type] (x1 : T1) [T2 : Type] (x2 : T2) (f : T1 -> T2) [n : nat] [s : seq T1],
    f x1 = x2 ->
    nth x2 [seq f i | i <- s] n = f (nth x1 s n).
Proof.
  intros.
  case/orP: (leqVgt (size s) n) => ineq.
  - by rewrite !nth_default // size_map.
  - by rewrite (nth_map x1).
Qed.
                                              
Lemma div_round_mul_add (a b : {poly int}) (d : int) :
  d <> 0 ->
  div_round (a + d *: b) d = div_round a d + b.
Proof.
  intros.
  rewrite /div_round !map_polyE -polyP => i.
  rewrite coefD !coef_Poly.
  rewrite !(nth_map_default 0 0); try by rewrite nearest_round_int0.
  rewrite coefD /=.
  by rewrite -nearest_round_int_mul_add_r // coefZ.
Qed.  

Lemma div_round_muln_add (a b : {poly int}) (d : nat) :
  d <> 0%N ->
  div_round (a + b *+ d) d = div_round a d + b.
Proof.
  intros.
  rewrite -div_round_mul_add; try lia.
  by rewrite -scaler_nat /GRing.scale /= !scale_polyE natz.
Qed.

Lemma div_round_muln (b : {poly int}) (d : nat) :
  d <> 0%N ->
  div_round (b *+ d) d = b.
Proof.
  intros.
  generalize (div_round_muln_add 0 b d H); intros.
  by rewrite add0r div_round0 add0r in H0.
Qed.

Lemma div_round_muln_add_l (a b : {poly int}) (d : nat) :
  d <> 0%N ->
  div_round (b *+ d + a) d = b + div_round a d.
Proof.
  intros.
  rewrite addrC div_round_muln_add //.
  by rewrite addrC.
Qed.

Lemma div_round_add2_ex (a b : {poly int}) (d : int) :
  d <> 0 ->
  { c : {poly int} |
    div_round (a + b) d = div_round a d + div_round b d + c /\
      icoef_maxnorm c <= 1}.
Proof.
  exists (div_round (a + b) d - (div_round a d + div_round b d)).
  split.
  - ring.
  - rewrite /icoef_maxnorm /div_round.
    apply /bigmax_leqP => i _.
    rewrite !(coefD,coefN).
    rewrite !coef_map_id0; try by rewrite nearest_round_int0.
    rewrite !coefD.
    by apply nearest_round_int_add2.
Qed.

Definition div_round_add2_perturb (a b : {poly int}) (d : int) (dn0 : d <> 0) :  {poly int}
  := sval (div_round_add2_ex a b d dn0).

Lemma div_round_add2_eq (a b : {poly int}) (d : int) (dn0 : d <> 0)   
  : div_round (a + b) d = div_round a d + div_round b d + 
                            div_round_add2_perturb a b d dn0.
Proof.
  rewrite /div_round_add2_perturb.
  case: (div_round_add2_perturb a b d dn0).
  case: div_round_add2_ex; intros; simpl.
  tauto.
Qed.

Lemma div_round_add2_perturb_small (a b : {poly int}) (d : int) (dn0 : d <> 0)
  : icoef_maxnorm (div_round_add2_perturb a b d dn0) <= 1.
Proof.
  rewrite /div_round_add2_perturb.
  case: (div_round_add2_perturb a b d dn0).
  case: div_round_add2_ex; intros; simpl.
  tauto.
Qed.

Definition q_reduce (q : nat) (p : {poly int}) : {poly 'Z_q} :=
  map_poly (fun c => c%:~R) p.

Lemma q_reduce_is_rmorphism (q : nat) :
  rmorphism (q_reduce q).
Proof.
  unfold q_reduce.
  apply map_poly_is_rmorphism.
Qed.        

Canonical q_reduce_rmorphism (q : nat) := RMorphism (q_reduce_is_rmorphism q).

Definition public_key {q : nat} (e s : {poly int}) (a : {poly 'Z_q})  : {poly {poly 'Z_q}} :=
  Poly [:: (- a * (q_reduce q s) + (q_reduce q e)); a].

Definition FHE_encrypt {q : nat} (p : {poly 'Z_q}) (v e0 e1 : {poly int}) (evkey : {poly {poly 'Z_q}}) :=
  Poly [:: (p + q_reduce q e0); q_reduce q e1] + (q_reduce q v) *: evkey.

Definition FHE_decrypt {q : nat} (s : {poly int}) (pp : {poly {poly 'Z_q}}) :=
  pp.[q_reduce q s].

Lemma decrypt_encrypt {q : nat} (e s v e0 e1 : {poly int}) (a p : {poly 'Z_q}) :
  FHE_decrypt s (FHE_encrypt p v e0 e1 (public_key e s a)) = 
    p + (q_reduce q e0) + q_reduce q e1 * q_reduce q s + q_reduce q v * q_reduce q e.
Proof.
  rewrite /FHE_decrypt /FHE_encrypt /public_key.
  rewrite hornerD hornerZ !horner_Poly /= mul0r !add0r.
  ring.
Qed.  

Lemma decrypt_add {q : nat} (P Q : {poly 'Z_q}) (PP QQ : {poly {poly 'Z_q}}) (s : {poly int}) :
  FHE_decrypt s PP = P ->
  FHE_decrypt s QQ = Q ->
  FHE_decrypt s (FHE_add PP QQ) = P + Q.
Proof.
  rewrite /FHE_decrypt /FHE_add.
  intros.
  by rewrite hornerD H H0.
Qed.

Lemma decrypt_mult_base {q : nat} (P Q : {poly 'Z_q}) (PP QQ : {poly {poly 'Z_q}}) (s : {poly int}) :
  FHE_decrypt s PP = P ->
  FHE_decrypt s QQ = Q ->
  FHE_decrypt s (FHE_mult_base PP QQ) = P * Q.
Proof.
  rewrite /FHE_decrypt /FHE_mult_base.
  intros.
  by rewrite hornerM H H0.
Qed.

Definition key_switch_key {q p : nat} (s s2 e : {poly int}) (a : {poly 'Z_(p*q)}) : {poly {poly 'Z_(p*q)}} := 
  Poly [:: (-a * (q_reduce (p * q) s) + (q_reduce (p * q) e) + q_reduce (p * q) (s2 *+ p)); a].

Definition ev_key {q p : nat} (s e : {poly int}) (a : {poly 'Z_(p*q)}) :=
  key_switch_key s (exp s 2) e a.

Definition linearize {q p : nat} (c0 c1 c2 : {poly 'Z_q}) 
  (evkey : {poly {poly 'Z_(p*q)}}) :=
  Poly [:: c0; c1] +
    map_poly (fun P => q_reduce q (div_round ((zlift c2) * (zlift P)) (p%:Z)))
                               evkey.

(* evkey = [:: (-a * (q_reduce (p * q) s) + (q_reduce (p * q) e) + (q_reduce (p * q) (s^2 *+ p))); a]
 *)
Ltac notHyp P :=
  match goal with
  | [ _ : P |- _ ] => fail 1
  | _ => idtac
  end.

Ltac extend_as_perturb P :=
  let t := type of P in
  notHyp t; generalize P;
  let x := (fresh "perturb_small") in
  intros x.

Ltac perturb_zlift_facts
  := repeat match goal with
       | [|- context [zlift_add2_perturb ?a ?b ?c]] =>
           extend_as_perturb (zlift_add2_perturb_small a b c)
       end.

Ltac perturb_div_round_facts
  := repeat match goal with
       | [|- context [div_round_add2_perturb ?a ?b ?c ?d]] =>
           extend_as_perturb (div_round_add2_perturb_small a b c d)
       end.

Lemma reduce_prod1 (p q : nat) (a : {poly int}) :
  q_reduce (q) (a *+ p) = (q_reduce q a) *+ p.
Proof.
  by rewrite rmorphMn.
Qed.

Lemma modn_mul2 (p q r: nat) : 
  p %% q * r = (p * r) %[mod q].
Proof.
  by rewrite modnMml.
Qed.

Lemma modn_mul2r (p q r: nat) : 
  r * (p %% q) = r * p %[mod q].
Proof.
  by rewrite modnMmr.
Qed.

Lemma modn_prod2 (p q n : nat) :
  ((n %% (p * q) * p) %% (p * q))%N = (n %% q * p)%N.
Proof.
  rewrite modn_mul2 (mulnC p _).
  by rewrite muln_modl.
Qed.

Lemma modn_prod2r (p q n : nat) :
  ((p * (n %% (p * q))) %% (p * q))%N = (p * (n %% q))%N.
Proof.
  by rewrite modn_mul2r muln_modr.
Qed.

Lemma reduce_prod2 (p q : nat) (a : int) :
  1 < q ->
  1 < p*q ->
  nat_of_ord ((a %:~R : 'Z_(p*q))*+ p) = ((a%:~R : 'Z_q) * p)%N.
Proof.
  intros.
  destruct a; rewrite /intmul !Zp_mulrn mul1n /inZp /= !Zp_cast //.
    by apply modn_prod2.
  - rewrite modn_prod2 //.
    f_equal.    
    rewrite !modnB; [|lia|lia|lia|lia].
    rewrite modnMl modnn !addn0.
    replace (modn (modn (S n) (muln p q)) q) with
      (modn (modn (S n) q) q); trivial.
    rewrite modn_mod modn_dvdm //.
    apply dvdn_mull.
    by apply dvdnn.
Qed.

Lemma div2_le (p q : nat) :
  (p <= q/2)%N = (2 * p <= q)%N.
Proof.
  move: (Nat.divmod_spec q 1 0 1 (le_refl _)) => /=.
  case: (Nat.divmod q 1 0 1) => /= x u.
  rewrite !Nat.add_0_r.
  move=> [-> ubound].
  destruct u; lia.
Qed.

Lemma liftc_reduce_prod2_nat (p q : nat) (a : nat) :
  1 < q ->
  1 < p*q ->
  zliftc ((a %:~R : 'Z_(p*q))*+ p) = (zliftc (a%:~R : 'Z_q)) *+p.
Proof.
  move=> qbig pqbig.
  rewrite /zliftc.
  have ->: ((a %:~R : 'Z_(p*q))*+ p <= p * q / 2) = (((a%:~R : 'Z_q)) <= q /2).
  {
    rewrite -mulr_natl !div2_le.
    rewrite /intmul !Zp_mulrn mul1n /inZp /= !Zp_cast //.
    rewrite [modn (S 0) (muln p q)]modn_small //.
    rewrite [modn (S 0) q]modn_small // !mul1n.
    rewrite modn_mul2 modn_prod2r.
    rewrite mulnA (mulnC 2%N p) -mulnA.
    rewrite leq_pmul2l //.
    lia.
  }
  case: leqP; rewrite reduce_prod2 //; lia.
Qed.

Lemma Nat_even_even (x : nat) : Nat.even x = ~~ odd x.
Proof.
  induction x => //=.
  destruct x; [lia |].
  by rewrite -IHx Nat.even_succ Nat.negb_odd.
Qed.  

Lemma Nat_odd_odd (x : nat) : Nat.odd x = odd x.
Proof.
  by rewrite -Nat.negb_even Nat_even_even negbK.
Qed.
  
Lemma qodd_half (q : nat) :
  odd q ->
  (q = q/2 + q/2 + 1)%N.
Proof.
  rewrite -!Nat.div2_div => qodd.
  rewrite [LHS]Nat.div2_odd Nat_odd_odd qodd /=.
  lia.
Qed.

Lemma liftc_neg0 (q : nat) (a : int) :
  1 < q ->
  (a %:~R : 'Z_q) = 0 ->
  zliftc ((-a)%:~R : 'Z_q) = - zliftc (a %:~R : 'Z_q).
Proof.
  intros.
  rewrite /zliftc.
  assert (((-a) %:~R : 'Z_q) = 0).
  {
    apply (f_equal (fun z => opp z)) in H0.
    rewrite -rmorphN /= in H0.
    by rewrite H0 oppr0.
  }
  rewrite H0 H1 /=; lia.
Qed.

Lemma liftc_neg_prop (q : nat) (a : 'Z_q) :
  (q = q/2 + q/2 + 1)%N ->
  q - a <= q/2 = ~~ (a <= q/2).
Proof.
  lia.
Qed.

Lemma liftc_neg_prop_alt (q : nat) (a : 'Z_q) :
  1 < q ->
  (q - a != a)%N ->
  q - a <= q/2 = ~~ (a <= q/2).
Proof.
  intros.
  generalize (Nat.div_mod_eq q 2); intros.
  assert (2 * (q/2) <= q)%coq_nat by lia.
  destruct a.
  simpl.
  simpl in H0.
  rewrite Zp_cast // in i.
  case: (boolP  (q - m <= q/2)); intros.
  - case (boolP (m <= q/2)); intros i0; rewrite i0; lia.
  - case (boolP (m <= q/2)); intros i1; rewrite i1; try tauto.
    assert ((q mod 2)%coq_nat < 2).
    {
      rewrite modulo_modn.
      by rewrite ltn_mod.
    }
    lia.
Qed.

Lemma Z_q_small {q:nat} (c : 'Z_q) :
  1 < q ->
  c < q.
Proof.
  move=> qbig.
  case: c => m i /=.
  by rewrite Zp_cast // in i.
Qed.

Lemma liftc_neg (q : nat) (a : int) :
  1 < q ->
  odd q ->
  (* ~~ intdiv.dvdz q (2 * a) *)
  zliftc ((-a)%:~R : 'Z_q) = - zliftc (a %:~R : 'Z_q).
Proof.
  move=> qbig qodd.
  rewrite /zliftc.
  move: (qodd_half q qodd) => qsum.
  move : (Z_q_small (a%:~R : 'Z_q) qbig) => asmall.
  case: (eqVneq (a %:~R : 'Z_q) 0)=>i; [by apply liftc_neg0|].
  assert (apos: 0 < (a%:~R : 'Z_q)).
  {
    have anneg: 0 <= (a%:~R : 'Z_q) by lia.
    by rewrite Order.NatOrder.ltn_def i anneg.
  } 

  have ->: (((- a)%:~R : 'Z_q) <= q / 2) = (~~ ((a%:~R : 'Z_q) <= q / 2)).
  {
    rewrite rmorphN /= {1 3}Zp_cast //.
    rewrite modnB; [|lia|lia].
    assert (0 < (a%:~R : 'Z_q) %% q).
    {
      rewrite modn_small //.
    }
    rewrite modnn H mul1n addn0 modn_small //.
    by apply liftc_neg_prop.
  }
  rewrite rmorphN /=.
  case: leqP => /=; intros; rewrite {1 3}Zp_cast // modn_small //; lia.
Qed.

Lemma liftc_neg_alt (q : nat) (a : int) :
  1 < q ->
  (q - (a%:~R : 'Z_q) != (a%:~R : 'Z_q))%N ->
  zliftc ((-a)%:~R : 'Z_q) = - zliftc (a %:~R : 'Z_q).
Proof.
  move=> qbig not_ahalf.
  rewrite /zliftc.
  move : (Z_q_small (a%:~R : 'Z_q) qbig) => asmall.
  case: (eqVneq (a %:~R : 'Z_q) 0)=>i; [by apply liftc_neg0|].
  assert (apos: 0 < (a%:~R : 'Z_q)).
  {
    have anneg: 0 <= (a%:~R : 'Z_q) by lia.
    by rewrite Order.NatOrder.ltn_def i anneg.
  } 

  have ->: (((- a)%:~R : 'Z_q) <= q / 2) = (~~ ((a%:~R : 'Z_q) <= q / 2)).
  {
    rewrite rmorphN /= {1 3}Zp_cast //.
    rewrite modnB; [|lia|lia].
    assert (0 < (a%:~R : 'Z_q) %% q).
    {
      rewrite modn_small //.
    }
    rewrite modnn H mul1n addn0 modn_small //.
    by apply liftc_neg_prop_alt.
  }
  rewrite rmorphN /=.
  case: leqP => /=; intros; rewrite {1 3}Zp_cast // modn_small //; lia.
Qed.

Lemma int_Zp_0 {q : nat} (a : int) :
  1 < q ->
  (a%:~R : 'Z_q) = 0 ->
  intdiv.modz a q = 0.
Proof.
  move => qbig.
  rewrite Zp_int //.
  move/(f_equal val).
  case: a => n ; rewrite /inZp /= Zp_cast //.
  - rewrite intdiv.modz_nat => ->; lia.
  - rewrite intdiv.modNz_nat; try lia.
    rewrite modnS.
    case: (boolP (q %| n.+1)%N) => pred a0.
    + suff: ((n %% q)%N = (q-1)%N) by lia.
      move /dvdnP in pred.
      case: pred => x xeq.
      have HH: (n + q = x * q + (q-1))%N by lia.
      have: ((n + q) %% q = (x * q + (q - 1)) %% q)%N.
      {
        by rewrite HH.
      }
      rewrite -modnDm -[RHS]modnDm modnn addn0 modnMl add0n modn_mod => ->.
      rewrite modn_mod modn_small; lia.
    + rewrite modn_small in a0; lia.
 Qed.

Lemma int_Zp_0_alt {q : nat} (a : int) :
  1 < q ->
  intdiv.modz a q = 0 ->
  (a%:~R : 'Z_q) = 0.
Proof.
  move => qbig qmod.
  rewrite Zp_int //.
  destruct a.
  - rewrite intdiv.modz_nat in qmod.
    apply ord_inj.
    rewrite /= Zp_cast //.
    lia.
  - rewrite intdiv.modNz_nat in qmod; try lia.
    apply ord_inj.
    rewrite /= Zp_cast //.
    rewrite modnS.
    case: (boolP (q %| n.+1)%N) => pred.
    + by rewrite subn0 modnn.
    + assert ((n%% q)%N = q-1)%N by lia.
      rewrite H.
      replace ((q-1).+1) with q by lia.
      by rewrite subnn mod0n.
Qed.    

Lemma int_Zp_0_iff (q : nat) (a : int) :
  1 < q ->
  intdiv.modz a q = 0 <->
  (a%:~R : 'Z_q) = 0.
Proof.
  move => qbig.
  split.
  - by apply int_Zp_0_alt.
  - by apply int_Zp_0.
Qed.

Lemma liftc_neg_alt_alt (q : nat) (a : int) :
  1 < q ->
  intdiv.dvdz q (2 * a) \/
    zliftc ((-a)%:~R : 'Z_q) = - zliftc (a %:~R : 'Z_q).
Proof.
  move=> qbig.
  case: (boolP (intdiv.dvdz q (2 * a))) => div; [by left|].
  right.
  apply liftc_neg_alt => //.
  move: div.
  apply contraNN => eqq.
  apply/intdiv.dvdzP.
  exists (intdiv.divz (2%Z * a) q).  
  have: 2 * (a%:~R : 'Z_q) == 0.
  {
    move: eqq.
    move/eqP/(f_equal (fun x:nat => x + (a%:~R : 'Z_q)))%nat.
    have aqsmall:  (a%:~R : 'Z_q) < q by apply Z_q_small.
    rewrite (_:(q - (a%:~R : 'Z_q) + (a%:~R : 'Z_q))%N =  q); [| lia].
    move => eqq.    
    suff: (a%:~R + a%:~R) == ( 0 : 'Z_q).
    {
      move/eqP => <-.
      apply/eqP.
      ring.
    }
    by rewrite /eq_op/= -eqq Zp_cast // modnn.
  }
  generalize (intdiv.divz_eq (2%Z*a) q); intros eqq2 a0.
  rewrite {1}eqq2.
  suff ->:(intdiv.modz (2%Z*a) q = 0).
  - by rewrite addr0.
  - rewrite -(intrM  (Zp_ringType (Zp_trunc q)) (2%Z) a) in a0.
    move /eqP in a0.
    by apply int_Zp_0.
Qed.    

Lemma liftc_reduce_prod2 (p q : nat) (a : int) :
  1 < q ->
  1 < p ->
  zliftc ((a %:~R : 'Z_(p*q))*+ p) = (zliftc (a%:~R : 'Z_q)) *+p.
Proof.
  move=> qbig pbig.
  assert (pqbig : 1 < p*q) by lia.
  rewrite /zliftc.
  have ->: ((a %:~R : 'Z_(p*q))*+ p <= p * q / 2) = (((a%:~R : 'Z_q)) <= q /2).
  {
    rewrite -mulr_natl !div2_le.
    destruct a; rewrite /intmul !Zp_mulrn mul1n /inZp /= !Zp_cast //.
    - rewrite [modn (S 0) (muln p q)]modn_small //.
      rewrite [modn (S 0) q]modn_small // !mul1n.
      rewrite modn_mul2 modn_prod2r.
      rewrite mulnA (mulnC 2%N p) -mulnA.
      rewrite leq_pmul2l //.
      lia.
    - rewrite (modn_small pqbig) (modn_small qbig) !mul1n.
      assert (p < p*q).
      {
        replace (p) with (p*1)%N at 1 by lia.
        rewrite ltn_pmul2l //; lia.
      }
      rewrite (modn_small H) -muln_modr.
      rewrite mulnA (mulnC 2%N p) -mulnA.
      rewrite leq_pmul2l; [| lia].
      assert ((((p * q - n.+1 %% (p * q)) %% (p * q)) %% q) =
                ((q - n.+1 %% q) %% q))%N.
      {
        rewrite modn_muln_r //.
        rewrite modnB; [|lia|lia].
        rewrite modnMl addn0.
        rewrite modn_muln_r //.
        case: ltP; intros.
        - rewrite mul1n.
          assert (q - n.+1 %% q < q) by lia.
          by rewrite (modn_small H0).
        - rewrite mul0n sub0n.
          assert (n.+1 %% q = 0)%N by lia.
          by rewrite H0 subn0 modnn.
      }
      by rewrite H0.
  }
  case: leqP; rewrite reduce_prod2 //; lia.
Qed.

Lemma lift_reduce_prod2 (p q : nat) (a : {poly int}) :
  1 < q ->
  1 < p ->
  zlift (q_reduce (p * q) a *+ p) =
    zlift (q_reduce q a) *+p.
Proof.
  intros.
  rewrite /zlift -polyP => i.
  rewrite coefMn !coef_map_id0 // coefMn.
  rewrite /q_reduce coef_map_id0 //.
  by apply liftc_reduce_prod2.
Qed.

Lemma zlift_valid {q : nat} (c : {poly 'Z_q}) :
  1 < q ->
  q_reduce q (zlift c) = c.
Proof.
  intros.
  rewrite /q_reduce /zlift -polyP => i.
  by rewrite !coef_map_id0 // zliftc_valid.
Qed.

Lemma linearize_prop_mult {q p : nat} (c2 : {poly 'Z_q})
  (s e : {poly int}) (a : {poly 'Z_(p*q)}) :
  let c2' := q_reduce (p*q) (zlift c2) in 
  (map_poly (fun P => c2' * P) (ev_key s e a)).[q_reduce (p * q) s] = 
    c2' * (q_reduce (p*q) (exp s 2) *+ p) + c2' * (q_reduce (p * q) e).
Proof.
  rewrite /ev_key /key_switch_key.
  rewrite map_Poly_id0; [|by rewrite mulr0].
  rewrite horner_Poly /= mul0r add0r.  
  rewrite !(zlift_add2_eq,mulrDr) rmorphMn /=.
  ring.
Qed.

Lemma linearize_prop_div {q p : nat} (c2 : {poly 'Z_q})
  (s e : {poly int}) (a : {poly 'Z_(p*q)}) :
  let c2' := q_reduce (p*q) (zlift c2) in 
  q_reduce q (div_round (zlift ((map_poly (fun P => c2' * P) (ev_key s e a)).[q_reduce (p * q) s])) p) = 
    q_reduce q (div_round (zlift (c2' * (q_reduce (p*q) (exp s 2) *+ p) + c2' * (q_reduce (p * q) e))) p).
Proof.
  simpl.
  by rewrite linearize_prop_mult.
Qed.

Lemma q_reduce_0_div (q : nat) (qbig: 1 < q) (p : {poly int}) :
  q_reduce q p = 0 ->
  { e : {poly int} | p = e *+ q}.
Proof.
  intros.
  exists (map_poly (fun c => intdiv.divz c q) p).
  apply polyP.
  intros ?.
  rewrite /q_reduce in H.
  rewrite coefMn coef_map_id0; [|by rewrite intdiv.div0z].
  rewrite [LHS](intdiv.divz_eq _ q).
  assert (intdiv.modz p`_x q = 0).
  {
    move: H.
    rewrite -(map_poly0 [eta intr]).
    move/polyP/(_ x).
    rewrite !coef_map_id0 //.
    rewrite coef0 /=.
    move/(f_equal val)=> /= HH.
    apply int_Zp_0 => //.
    by apply ord_inj.
  } 
  lia.
Qed.

Lemma poly_Zq_muln_q {q : nat} (qbig:1 < q) (a : {poly 'Z_q}) :
  a *+ q = 0.
Proof.
  rewrite -polyP => i.
  rewrite coefMn coef0 Zp_mulrn.
  apply ord_inj => /=.
  by rewrite {3}Zp_cast // modnMl.
Qed.

Lemma q_reduce_muln_q (q : nat) (qbig:1 < q) (a : {poly int}) :
  q_reduce q (a *+ q) = 0.
Proof.
  by rewrite reduce_prod1 poly_Zq_muln_q.
Qed.

Lemma zlift_red (q : nat) (p : {poly int}) :
  1 < q ->
  { e : {poly int} |
    zlift (q_reduce q p) = p + e *+q}.
Proof.
  intros.
  assert (q_reduce q (zlift (q_reduce q p) - p) = 0).
  {
    rewrite rmorphD rmorphN /= zlift_valid //.
    ring.
  }
  apply q_reduce_0_div in H0 => //.
  destruct H0.
  exists x.
  rewrite -e.
  ring.
Qed.
Lemma linearize_prop_div2 {q p : nat} (qbig : 1 < q) (pbig : 1 < p) (c2 : {poly 'Z_q})
  (s e : {poly int}) (a : {poly 'Z_(p*q)}) :
  let c2' := q_reduce (p*q) (zlift c2) in 
  { e2 : {poly int} |
    q_reduce q (div_round (zlift (c2' * (q_reduce (p*q) (exp s 2) *+ p) + c2' * (q_reduce (p * q) e))) p) =
    c2 * (q_reduce q (exp s 2)) + q_reduce q (div_round ((zlift c2) * e) p + e2)}.
Proof.
  assert (pqbig: (1 < p * q)) by lia.
  assert (pno: (Posz p <> 0)) by lia.
  destruct (zlift_red (p * q) (zlift c2 * e) pqbig).
  exists
    (
     div_round_add2_perturb (zlift c2 * e) (x *+ (p * q)) p pno +
     div_round
       (zlift_add2_perturb pqbig (q_reduce (p * q) (zlift c2 * s ^+ 2) *+ p)
          (q_reduce (p * q) (zlift c2 * e))) p +
     div_round_add2_perturb
       (zlift (c2 * q_reduce q (s ^+ 2)) *+ p + zlift c2 * e + x *+ (p * q))
       (zlift_add2_perturb pqbig (q_reduce (p * q) (zlift c2 * s ^+ 2) *+ p)
          (q_reduce (p * q) (zlift c2 * e))) p pno).
  rewrite (zlift_add2_eq,mulrDr) //.
  rewrite div_round_add2_eq //.
  rewrite !rmorphD /= -rmorphMn -rmorphM /=.
  rewrite mulrnAr rmorphMn /=.
  rewrite lift_reduce_prod2 //.
  rewrite div_round_muln_add_l; [|lia].
  rewrite rmorphD /=.
  rewrite zlift_valid // rmorphM /= zlift_valid // -!addrA.
  f_equal.
  rewrite -rmorphM /=.
  rewrite e0.
  rewrite div_round_add2_eq // !rmorphD /= -!addrA.
  replace (q_reduce q (div_round (x *+ (p * q)) p)) with (0 : {poly 'Z_q}).
  - by rewrite add0r.
  - rewrite mulnC mulrnA.
    assert (p <> 0%N) by lia.
    by rewrite div_round_muln // q_reduce_muln_q.
Qed.

Lemma lineariz_prop_div3 {q p : nat} (qbig : 1 < q) (pbig : 1 < p) (c2 : {poly 'Z_q})
  (s e : {poly int}) (a : {poly 'Z_(p*q)}) :
  let c2' := q_reduce (p*q) (zlift c2) in 
  { e2 : {poly 'Z_q} |
    q_reduce q (div_round (zlift ((map_poly (fun P => c2' * P) (ev_key s e a)).[q_reduce (p * q) s])) p) =
      (map_poly (fun P => q_reduce q (div_round ((zlift c2) * (zlift P)) (p%:Z)))
         (ev_key s e a)).[q_reduce q s] + e2}.
Proof.
  assert (pqbig: (1 < p * q)) by lia.
  assert (pno: (Posz p <> 0)) by lia.
  eexists.
  rewrite !map_Poly_id0.
  + rewrite !horner_Poly /= !mul0r !add0r.
    rewrite zlift_add2_eq.
    rewrite !div_round_add2_eq !rmorphD /=.
    rewrite -!addrA.
    f_equal.
    * admit.
    * admit.
  + by rewrite zlift0_alt mulr0 div_round0 rmorph0.
  + by rewrite mulr0.
  Admitted.

Lemma linearize_prop  {q p : nat} (qbig : 1 < q) (pbig : 1 < p) (c2 : {poly 'Z_q}) (s e : {poly int}) (a : {poly 'Z_(p*q)}) :
  { e2 : {poly int} |
    (map_poly (fun P => q_reduce q (div_round ((zlift c2) * (zlift P)) (p%:Z)))
     (ev_key s e a)).[q_reduce q s] = 
      c2 * (q_reduce q (exp s 2)) + q_reduce q (div_round ((zlift c2) * e) p + e2) /\
  icoef_maxnorm e2 <= 1}. 
Proof.
  assert (pqbig: (1 < p * q)) by lia.
  assert (pno: (Posz p <> 0)) by lia.
  eexists; split.
  - rewrite /ev_key /key_switch_key.
    rewrite map_Poly_id0.
    + rewrite horner_Poly /= mul0r add0r.
      rewrite !(zlift_add2_eq,mulrDr) rmorphMn /=.
      rewrite div_round_add2_eq.
      rewrite lift_reduce_prod2 // mulrnAr /=.
      rewrite div_round_muln_add; try lia.
      rewrite !rmorphD /=.
      rewrite rmorphM /=.
      rewrite !zlift_valid //.
      rewrite !div_round_add2_eq !rmorphD /=.
      admit.
    + by rewrite [zlift 0]zlift0 // mulr0 div_round0 rmorph0.
  - admit.
Admitted.

Definition rescale {q1 q2 : nat} (p : {poly 'Z_(q1 * q2)}) : {poly 'Z_q2} :=
  q_reduce q2 (div_round (zlift p) q1%:Z).

Definition FHE_mult  {q p : nat} (P Q : {poly {poly 'Z_q}}) 
  (evkey : {poly {poly 'Z_(p*q)}}) :=
  let PQ := FHE_mult_base P Q in
  linearize (PQ`_0) (PQ`_1) (PQ`_2) evkey.

Lemma decrypt_mult {p q : nat} (P Q : {poly 'Z_q}) (PP QQ : {poly {poly 'Z_q}}) 
  (s e : {poly int}) (a : {poly 'Z_(p*q)}) :
  FHE_decrypt s PP = P ->
  FHE_decrypt s QQ = Q ->
  size PP = 2%N ->
  size QQ = 2%N ->
  {R : {poly int} |
     FHE_decrypt s (FHE_mult PP QQ (ev_key s e a)) = 
       P * Q + q_reduce q (div_round (zlift (PP * QQ)`_2 * e) p + R) /\
       icoef_maxnorm R <= 1 }.
Proof.
(*
  intros.
  rewrite -(decrypt_mult_base P Q PP QQ s) //.
  rewrite /FHE_mult /linearize /FHE_mult_base /FHE_decrypt hornerD.
  rewrite linearize_prop.
  assert (size (PP * QQ) <= 3%N).
  {
    generalize (size_mul_leq PP QQ); intros.
    by rewrite H1 H2 in H3.
  }
  replace (q_reduce q (s ^+ 2)) with
    ((q_reduce q s) ^+ 2).
  - assert (PP * QQ = Poly [:: (PP * QQ)`_0; (PP * QQ)`_1; (PP * QQ)`_2]).
    {
      replace (PP * QQ) with (take_poly 3 (PP * QQ)) at 1.
      - unfold take_poly.
        rewrite -polyP.
        intros ?.
        rewrite coef_poly coef_Poly.
        case: leqP => ineq.
        + by rewrite nth_default.
        + by rewrite -(nth_mkseq 0 (fun i => (PP * QQ)`_i) ineq).
      - rewrite take_poly_id //.
    }
    rewrite {5}H4 !horner_Poly /= mul0r !add0r mulrDl addrC -!addrA.
    f_equal.
    + by rewrite expr2 mulrA.
    + by rewrite addrC addrA.
  - by rewrite rmorphXn.
Qed.
 *)
  Admitted.

Definition key_switch {q p : nat} (c0 c1 : {poly 'Z_q})
  (ks_key : {poly {poly 'Z_(p*q)}}) : {poly {poly 'Z_q}} :=
  c0%:P + map_poly (fun P => q_reduce q (div_round ((zlift c1) * (zlift P)) (p%:Z)))
                   ks_key.
  
Definition FHE_automorphism  {q p : nat} (s e : {poly int}) 
                     (a : {poly 'Z_(p*q)}) (P : {poly {poly 'Z_q}}) (j : nat) :=
  key_switch (comp_poly 'X^(2*j+1) P`_0)
    (comp_poly 'X^(2*j+1) P`_1)
    (key_switch_key s (comp_poly 'X^(2*j+1) s) e a).

Lemma decrypt_FHE_automorphism_base  {q p : nat} (s : {poly int}) (P : {poly 'Z_q})
  (PP : {poly {poly 'Z_q}}) (j : nat) :
  FHE_decrypt s PP = P ->
  comp_poly 'X^(2*j+1) P = FHE_decrypt (comp_poly 'X^(2*j+1) s)
                                       (map_poly (comp_poly 'X^(2*j+1)) PP).
Proof.
  rewrite /FHE_decrypt.
  intros.
  replace (q_reduce q (s \Po 'X^(2 * j + 1))) with
    (comp_poly 'X^(2*j+1) (q_reduce q s)).
  - by rewrite horner_map /= H.
  - rewrite /q_reduce map_comp_poly /=.
    f_equal.
    by rewrite map_polyXn.
Qed.
    
