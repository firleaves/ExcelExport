
*表放在excels文件夹下面，有用的reference特性的，被引用的表放到excels目录下面，不要放到exces子目录中*


# 生成lua表规则

#@ 表格前四行是固定的

* 第一行注释
* 第二行字段名
* 第三行类型
* 第四行默认为空,哪个字段需要给客户端用,服务器不需要用,就写1。可以是空行，但不能没有，而且改行第1列必须为空。（不然会报警告，且不会生成lua文件）


## 支持类型

* int    整数
* int[] 整形数组， 格式 11;13;45
* int[][] 整形二维数组  格式 11;13;45|11;13;45
* float   浮点数
* float[] 浮点数组 格式如同int[]
* mapi   整形字典类型<int,int> 比如 2,3|5,2 生成 {[2]=3,[5] = 2}这种数据
* string 字符串
* bool 真假值,支持true/false 也支持0/1
* raw 原始字符串,会生成出table ,比如你需要每一行写不同的东西,写成 a=10,b=11,会生成出表 {a = 10,b = 11},注意这里字符串是符合lua规则的才行
* date 日期  格式为 2021/6/11 12:00:00  [年/月/日 小时:分钟:秒数]
* struct 自定义格式,用<>包含内容,内容为<字段:字段类型,字段:字段类型>,仅支持 int,float,string,bool,raw这几个类型,数据填写用 ; 分割 比如struct<id:int,name:string,gold:int,man:bool >
内容写10;test;100;true
* structTable自定义表格式，同struct使用方法，另支持int[]一维数组类型，数据填写用 ; 分割 比如：structTable<id:int,buffs:int[]>内容写1;2,3,4|2;3,4,5,6 
* reference 引用其他表格,会把其他表格内容嵌套进去,用<>包含其他表格名，如reference<skillLevel> *被引用的表格就不会生成,仅支持一级嵌套,不要搞多层嵌套,或者你可以加代码支持*  支持两种其他表格id索引，第一种范围引用 格式 x~y  会把[x,y]范围内数据引用进来，第二种是具体id引用，比如 11;15;16;17 会引用其他表格的11 15 16 17的数据
* const 1.常量类型，根据内容自动匹配int,float,bool,string类型；2.满足以下条件时：a.表中一共两列，其中一列名字是"#const"，类型是const，则最终生成的数据是map类型，value是"#const"指向的值，key是另一列对应的值

## 代码在Tools文件夹下面的lua文件内
Tools内有所有支持类型范例文件 test.xlsx 和 导出的test.lua