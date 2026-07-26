    .set SYS_exit, 0x01
    .set SYS_read, 0x03
    .set SYS_write, 0x04
    .set SYS_open, 0x05
    .set STDIN_FILENO, 0
    .set STDOUT_FILENO, 1
    .set STDERR_FILENO, 2
    .set O_RDONLY, 0
    .set O_WRONLY, (1 << 0)
    .set O_RDWR, (1 << 1)
