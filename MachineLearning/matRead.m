%读取Mat数据的函数
function data=matRead(filename)
inp=load(filename);
f=fields(inp);
data=inp.(f{1});
