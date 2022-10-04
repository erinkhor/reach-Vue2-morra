'reach 0.1';

// create enum for first 5 fingers
//const [ isHand, ZERO, ONE, TWO, THREE, FOUR, FIVE ] = makeEnum(6);

// create enum for results
const [ isResult, NO_WINS, E_WINS, K_WINS, DRAW,  ] = makeEnum(4);

// 0 = none, 1 = B wins, 2 = draw , 3 = E wins
const winner = (handErin, guessErin, handKhor, guessKhor) => {
  const total = handErin + handKhor;

  if ( guessErin == total && guessKhor == total  ) {
      // draw
      return DRAW
  }  else if ( guessKhor == total) {
      // Khor wins
      return K_WINS
  }
  else if ( guessErin == total ) { 
      // Erin wins
      return E_WINS
  } else {
    // else no one wins
      return NO_WINS
  }
 
}
  
assert(winner(1,2,1,3 ) == E_WINS);
assert(winner(5,10,5,8 ) == E_WINS);

assert(winner(3,6,4,7 ) == K_WINS);
assert(winner(1,5,3,4 ) == K_WINS);

assert(winner(0,0,0,0 ) == DRAW);
assert(winner(2,4,2,4 ) == DRAW);
assert(winner(5,10,5,10 ) == DRAW);

assert(winner(3,6,2,4 ) == NO_WINS);
assert(winner(0,3,1,5 ) == NO_WINS);

forall(UInt, handErin =>
  forall(UInt, handKhor =>
    forall(UInt, guessErin =>
      forall(UInt, guessKhor =>
    assert(isResult(winner(handErin, guessErin, handKhor , guessKhor)))
))));


// Setup common functions
const commonInteract = {
  ...hasRandom,
  reportResult: Fun([UInt], Null),
  reportHands: Fun([UInt, UInt, UInt, UInt], Null),
  informTimeout: Fun([], Null),
  getHand: Fun([], UInt),
  getGuess: Fun([], UInt),
};

const erinInterect = {
  ...commonInteract,
  wager: UInt, 
  deadline: UInt, 
}

const khorInteract = {
  ...commonInteract,
  acceptWager: Fun([UInt], Null),
}


export const main = Reach.App(() => {
  const Erin = Participant('Erin',erinInterect );
  const Khor = Participant('Khor', khorInteract );
  init();

  // Check for timeouts
  const informTimeout = () => {
    each([Erin, Khor], () => {
      interact.informTimeout();
    });
  };

  Erin.only(() => {
    const wager = declassify(interact.wager);
    const deadline = declassify(interact.deadline);
  });
  Erin.publish(wager, deadline)
    .pay(wager);
  commit();

  Khor.only(() => {
    interact.acceptWager(wager);
  });
  Khor.pay(wager)
    .timeout(relativeTime(deadline), () => closeTo(Erin, informTimeout));
  

  var result = DRAW;
   invariant( balance() == 2 * wager && isResult(result) );

   ///////////////// While DRAW or NO_WINS //////////////////////////////
   while ( result == DRAW || result == NO_WINS ) {
    commit();

  Erin.only(() => {
    const _handErin = interact.getHand();
    const [_commitErin1, _saltErin1] = makeCommitment(interact, _handErin);
    const commitErin1 = declassify(_commitErin1);

    const _guessErin = interact.getGuess();
    const [_commitErin2, _saltErin2] = makeCommitment(interact, _guessErin);
    const commitErin2 = declassify(_commitErin2);

  })
  

  Erin.publish(commitErin1, commitErin2)
      .timeout(relativeTime(deadline), () => closeTo(Khor, informTimeout));
    commit();

  // Khor must NOT know about Erin hand and guess
  unknowable(Khor, Erin(_handErin,_guessErin, _saltErin1,_saltErin2 ));
  
  // Get Khor hand
  Khor.only(() => {
    const handKhor = declassify(interact.getHand());
    const guessKhor = declassify(interact.getGuess());
  });

  KHor.publish(handKhor, guessKhor)
    .timeout(relativeTime(deadline), () => closeTo(Erin, informTimeout));
  commit();

  Erin.only(() => {
    const saltErin1 = declassify(_saltErin1);
    const handErin = declassify(_handErin);
    const saltErin2 = declassify(_saltErin2);
    const guessErin = declassify(_guessErin);

  });

  Erin.publish(saltErin1,saltErin2, handErin, guessErin)
    .timeout(relativeTime(deadline), () => closeTo(Khor, informTimeout));
  checkCommitment(commitErin, saltErin1, handErin);
  checkCommitment(commitErin2, saltErin2, guessErin);

  // Report results to all participants
  each([Erin, Khor], () => {
    interact.reportHands(handErin, guessErin, handKhor, guessKhor);
  });

  result = winner(handErin, guessErin, handKhor, guessKhor);
  continue;
}
// check to make sure no DRAW or NO_WINS
assert(result == E_WINS || result == K_WINS);

each([Erin, Khor], () => {
  interact.reportResult(result);
});

transfer(2 * wager).to(result == E_WINS ? Erin : Khor);
commit();

});
