# 1 应用场景
- 在使用Synopsys VC_Spyglass工具执行跨时钟域检查时，可能会涉及到对比不同版本cdc_report的问题。针对特定项目，我们需要评估以下两种情况：
  - 项目1需要比较添加sam_model和添加waive_ip的cdc_report；
  - 项目2需要比较netlist和rtl的cdc_report。
- 此脚本旨在高效并精确地比较这两种场景下的cdc_report。

# 2 脚本介绍
- 脚本分为四部分：准备工作、sam_waive模式、netlist_rtl模式和计算运行时间。
