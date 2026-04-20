
#!/usr/bin/env bash
make clean 
make bench VDEFINES="-DTEST_MODE_BRANCH"