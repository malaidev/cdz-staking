# TODO

*so far*
- [x] smart way to calculate daysStaked
    - block.timestamp is the trusted way to do so
- [x] smart way to define maturity time
    - simple require check will do the job
- [x] handling the floats
    - float operations will happen in oracle
- [ ] test cases for harvest and other admin functions
- [ ] solution for returning UserInfo struct for frontend
- [x] managing fees and their acquisition during stake and harvest
    - needs some polishing but its done
- [ ] burning
- [x] exploit in unstake function
    - fixed with power of bool and double mapping
- [ ] amountOfstakers, each user must be unique

*note, test cases will fail after last update*
