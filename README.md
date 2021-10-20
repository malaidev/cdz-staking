# TODO

*so far*
- [x] smart way to calculate daysStaked
    - block.timestamp is the trusted way to do so
- [x] smart way to define maturity time
    - simple require check will do the job
- [x] handling the floats
    - float operations will happen in oracle
- [x] solution for returning UserInfo struct for frontend
    - we can do it w lil bit of syntax manipulation, also we avoid returning mappings (we dont need them)
- [x] managing fees and their acquisition during stake and harvest
    - needs some polishing but its done
- [ ] burning
- [x] exploit in unstake function
    - fixed with power of bool and double mapping
- [x] amountOfstakers, each user must be unique
    - fixed by if statement in stake function
- [ ] improve daysStakedMultiplier, so it multiplies in every fixed period
- [ ] unit testing

*note, test cases will fail after last update*
