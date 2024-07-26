# 1 应用场景
- 在使用Synopsys VC_Spyglass工具执行跨时钟域检查时，可能会涉及到对比不同版本cdc_report的问题。针对特定项目，我们需要评估以下两种情况：
  - 项目1需要比较添加sam_model和添加waive_ip的cdc_report；
  - 项目2需要比较netlist和rtl的cdc_report。
- 此脚本旨在高效并精确地比较这两种场景下的cdc_report。

# 2 脚本介绍
- 脚本分为4部分：准备工作、sam_waive模式、netlist_rtl模式和计算运行时间。
- Part1 准备工作：
	- 定义函数；
	- 输入参数；
	- 定义数组和哈希。
- Part2 `sam_waive`模式：
	- 遍历`$FILE1`4次，第1次使用`awk`捕获描述`error`的总行数，第2次处理`setup_tag`，第3次处理`conv_tag`，第4次使用`awk`处理`ordinary_tag`；
	- 遍历`$FILE2`4次，第1次使用`awk`捕获描述`error`的总行数，第2次处理`setup_tag`，第3次处理`conv_tag`，第4次使用`awk`处理`ordinary_tag`；
	- 针对`setup_tag`进行比较；
	- 针对`conv_tag`进行比较；
	- 针对`ordinary_tag`进行比较。
- Part3 `netlist_rtl`模式：
	- 遍历`$FILE1`4次，第1次使用`awk`捕获描述`error`的总行数，第2次处理`setup_tag`，第3次处理`conv_tag`，第4次使用`awk`处理`ordinary_tag`；
	- 遍历`$FILE2`4次，第1次使用`awk`捕获描述`error`的总行数，第2次处理`setup_tag`，第3次处理`conv_tag`，第4次使用`awk`处理`ordinary_tag`；
	- 针对`setup_tag`进行比较；
	- 针对`conv_tag`进行比较；
	- 针对`ordinary_tag`进行比较。
	- 注：`sam_waive`模式和`netlist_rtl`模式的不同之处在于：
		- 对特殊端口如`abc_reg_30__301_/Q(N)`的处理方式；
		- 对`waive`的处理方式。
- Part4 计时功能：逻辑实现较为简单，不多做讲解。
