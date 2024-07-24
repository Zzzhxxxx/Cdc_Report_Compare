# 1 应用场景
- 在执行跨时钟域检查时，使用Synopsys VC_Spyglass工具可能会涉及到对比不同检查版本的结果。针对特定项目，我们需要评估以下两种情况：
  - 项目1需要比较添加sam_model和waive_ip的cdc结果；
  - 项目2需要比较netlist和rtl的cdc结果。
- 为此，我开发了此脚本，旨在自动化并精确地比较这两种场景下的cdc结果。

# 2 脚本介绍
- 脚本分为四部分：准备工作、sam_waive模式、netlist_rtl模式和计算运行时间。
