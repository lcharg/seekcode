# TDD 红证据留痕(宪章 4.1)

`/implement-spec` 第 2 步在此目录存放"测试先失败"的原始输出,文件名格式:

```
SPEC-0xx-<YYYY-MM-DD>-red.txt
```

内容为实现前 `cargo test specNNN` 的完整失败输出。本目录**入库**,是 tdd-guard 与 CI 验证红-绿顺序的依据;不得事后补写或篡改(git 历史可审计)。
