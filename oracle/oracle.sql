asdf;a;
--dml dcl ddl


--登录sqlplus
sqlplus / as sysdba;
sqlplus 
conn scott/tiger

--执行sql文件
sqlplus -S walker/qwer@127.0.0.1@orcl @SQL.sql



----------------------------------------------用户角色
--update user pwd
create user username identified by password;    --drop user username cascade; --link to all 
grant dba,connect,resource,EXP_FULL_DATABASE,IMP_FULL_DATABASE to walker;    -- revoke connect, resource from walker;
--查看所有用户所拥有的角色
SELECT * FROM DBA_ROLE_PRIVS;

-----------------------------------------------表空间
--创建
create tablespace 表间名 datafile '数据文件名' size 表空间大小;
create tablespace tablespace_name datafile 'tablespace_name.ora' size 128M autoextend on next 128M maxsize 10240M;    --unlimited; 

--修改
ALTER DATABASE DATAFILE 'data_1.ora' AUTOEXTEND ON;--打开自动增长
ALTER DATABASE DATAFILE 'data_1.ora' AUTOEXTEND ON NEXT 200M ;--每次自动增长200m
ALTER DATABASE DATAFILE 'data_1.ora' AUTOEXTEND ON NEXT 200M MAXSIZE 1024M;--每次自动增长200m，数据表最大不超过1G
--级联删除文件 
drop tablespace  tablespace_name  including contents and datafiles cascade constraints;
--删除表空间却没删除文件的问题 再次复用文件后 级联删除
create tablespace TEST datafile 'tablespace_name.ora' ;

---
---用户相关数据查询
---

--查看当前用户的所有序列 
select SEQUENCE_OWNER,SEQUENCE_NAME,last_number from dba_sequences  ; 

--查看各个表空间占用;
select tablespace_name, sum(bytes) / 1024 / 1024 MB  from dba_free_space  group by tablespace_name order by 2 desc;  
--各个用户表数
select owner,count(1) cc from dba_tables where 1=1 group by owner order by 2 desc;
--各个用户表行数
select t.owner,t.table_name,t.tablespace_name,t.num_rows　from dba_tables t where t.NUM_ROWS is not  null  order by t.NUM_ROWS  desc 
--查看各个用户表总大小
SELECT s.owner, to_number(SUM(s.BYTES)/1024/1024) MB from dba_segments s where 1=1 group by s.owner order by 2 desc;
--某用户每个表大小 清理
SELECT s.owner, s.segment_name,to_number((s.BYTES)/1024/1024) MB from dba_segments s where s.owner='WALKER' order by 3 desc;
--查看创建表语句表结构
SET LONG 3000
SET PAGESIZE 0
SELECT DBMS_METADATA.GET_DDL('TABLE','STUDENT') FROM DUAL;

--查看用户和默认表空间的关系
select username,default_tablespace from dba_users;
--查看当前用户能访问的表
select * from user_tables; 
--Oracle查询用户表
select * from user_all_tables;
--Oracle查询用户视图
select * from user_views;
--查询所有函数和储存过程：
select * from user_source;
--查询所有用户：
select * from all_users;
--select * from dba_users
--查看用户角色
SELECT * FROM USER_ROLE_PRIVS;
--查看当前用户权限：
select * from session_privs;
--查看所有用户所拥有的角色
SELECT * FROM DBA_ROLE_PRIVS;
--查看所有角色
select * from dba_roles;
--查看数据库名
SELECT NAME FROM V$DATABASE;

--show table column 表列信息
select * from all_tab_columns where table_name = upper('student') order by column_id
--show index
select * from user_indexs where table_name = upper('student') order by column_id
--show table create sql (index column) 查看建表语句
select dbms_metadata.get_ddl('TABLE', 'STUDENT') from dual;

---
---dblink 跨数据库数据操作
---

-- 查看wangyong用户是否具备创建database link 权限
select * from user_sys_privs where privilege like upper('%DATABASE LINK%') AND USERNAME='WANGYONG';
-- 给wangyong用户授予创建dblink的权限
grant create public database link to wangyong; 
-- 注意一点，如果密码是数字开头，用''括起来
create public database link TESTLINK2 connect to WANGYONG identified by '123456' USING '122.23.12.13/orcl'


grant CREATE PUBLIC DATABASE LINK，DROP PUBLIC DATABASE LINK to scott;
create database link DBLINK_NAME connect to USER01 identified by PASSWORD using 'TNS_NAME';
DBLINK_NAME : DB_LINK的名字
USER01　　     : 远程数据库的账户
PASSWORD      : 远程数据库的账户
TNS_NAME      : 远程数据库服务名 122.2312.13/orcl
select owner,db_link,username from dba_db_links;
--查询link
select * from scott.tb_test@DBLINK_NAME;


---
---导入导出
---

--导入导出文件夹 创建文件夹 权限 oracle dba?
create directory backup as '/home/backup';  --drop directory backup;
grant read,write on directory backup to walker;
--导出数据库
expdp user1/password@orcl diretory=backup dumpfile=test.dmp schemas=user1;     
--导入数据库到某用户
impdp user2/password@orcl diretory=backup dumpfile=test.dmp remap_schema=user1:user2 remap_tablespace=user1_space:user2_space;

--查询表空间中数据文件具体位置和文件名
Select * FROM DBA_DATA_FILES;

--数据文件路径默认在$ORACLE_HOME/oradata/$SID


---
---oracle 用户进程 sql 死锁
---
 
--查看oracle 设置 进程 会话 死锁  sql
select * from v$parameter;
select * from v$proccess;
select * from v$session;
select * from v$locked_object;
select * from v$sql;
select sid, serial#, username, osuser from v$session;-- where sid=783;
--查找死锁并杀掉
select sid||','||serial# kill, sid, serial#, username, osuser from v$session where sid in (select session_id from v$locked_object)
alter system kill session '783,18455';
--查找每个session的上一条执行sql 等待 当前sql 
select sql.sql_text prev_sql, sql.sql_id psql_id, s.*  from v$session s, v$sql sql where s.prev_sql_id = sql.sql_id;
--&&并统计每个session的prev_sql的个数 分组 用户 程序等
select count(1) cc, ssql_id, prev_sql, username, program from (
    select sql.sql_text prev_sql, sql.sql_id psql_id, s.*  from v$session s, v$sql sql where s.prev_sql_id = sql.sql_id
) group by ssql_id, prev_sql, username, program
order by username, cc desc

--查找某sql的执行记录 上次执行的ip port 历史sql记录分析
select t.parsing_schema_name,t.sql_text,t.sql_id,t.last_active_time,t.action,t.module
,h.session_id,h.machine,h.port,h.user_id,h.sql_opname,h.sample_time 
from v$sqlarea t,dba_hist_active_sess_story h
whre 1=1
and ( upper(sql_text) like '%DELETE%XXX%' )
and h.sql_id=t.sql_id
order by t.last_actie_time desc
;

--查找分析每个用户的连接数
select count(1) cc, username from v$session group by username;


---
--- sql debug sql优化
---

--awr setting， STATISTICS_LEVEL: TYPICAL or ALL, open AWR； BASIC，close AWR
SHOW PARAMETER STATISTICS_LEVEL
alter system set statistics_level=typical; --alter system
alter session set statistics_level=typical; --alter only now session

--get awr report
D:\app\product\11.1.0\db_1\RDBMS\ADMIN run awrrpt.sql

--plan_table F5 执行计划
select * from plan_table where statement_id＝'...'
Description列描述当前的数据库操作，
Object owner列表示对象所属用户，
Object name表示操作的对象，
Cost列表示当前操作的代价（消耗），这个列基本上就是评价SQL语句的优劣，
Cardinality列表示操作影响的行数，
Bytes列表示字节数

--从左至右从上到下 对应ROWS/基数
--表的访问方式主要是两种：全表扫描（TABLE ACCESS FULL）和索引扫描(INDEX SCAN)，如果表上存在选择性很好的索引，却走了全表扫描，而且是大表的全表扫描，就说明表的访问方式可能存在问题；若大表上没有合适的索引而走了全表扫描，就需要分析能否建立索引，或者是否能选择更合适的表连接方式和连接顺序以提高效率。
TABLE ACCESS FULL   --all table scan
INDEX SCAN          --index scan
join types --嵌套循环（NESTED LOOPS）、哈希连接（HASH JOIN）和排序-合并连接（SORT MERGE JOIN）。


---
---user control
---

--unlock 
alter user scott account unlock; 


---
-- table control ddl 数据库建表 索引
---

--create
create table test(id varchar(20), time date);
create table test ( id varchar(20) primary key, time date, num number(3, 1), test varchar(20) not null, value varchar(20) default 'about' );
--1.create
create table table_name_new as select * from table_name_old 
--2.create
create table table_name_new as select * from table_name_old where 1=2; 
create table table_name_new like table_name_old 
--分区分表创建 分区hash键 索引 已有数据的表 新建转移数据后重命名
create table test(id1 varchar(20), id2 varchar(20), value varchar(200))
partition by hash(id1)(
    partition P01,
    partition P02,
    partition P03,
    partition P04
);
create index i_test_id1 on test(id1, id2);
select * from test partition(P01);  --查询分区
    


-- delete the table 
drop  table test  ;

--index
alter table tb_a add  foreign key(id ) references tb_b(id);

--alter table index DML时，会更新索引。因此索引越多，则DML越慢，其需要维护索引。 因此在创建索引及DML需要权衡 index 只对 =  ,like 'key%'有效
alter table tb_group add( checked varchar(10) default 'true' );
alter table tb_group rename column checked to newname;
alter table tb_group modify column_name varchar2(340) not null;
alter table tb_group add unique(user_token);
Create Index i_deptno_job on emp(deptno,job); —>在emp表的deptno、job列建立索引。
--改表名字
RENAME student TO student_OLD; 
--数据查询缓慢 优化 

--2.数据量大 加索引 f5执行计划 避免 全表扫描 table_access_full
--1.sql优化
--3.awr报告分析

1、先执行From ->Where ->Group By->Order By
2、执行From 字句是从右往左进行执行。因此必须选择记录条数最少的表放在右边。这是为什么呢？　　
3、对于Where字句其执行顺序是从后向前执行、因此可以过滤最大数量记录的条件必须写在Where子句的末尾，而对于多表之间的连接，则写在之前。
因为这样进行连接时，可以去掉大多不重复的项。　　
4. SELECT子句中避免使用(*)ORACLE在解析的过程中, 会将’*’ 依次转换成所有的列名, 这个工作是通过查询数据字典完成的, 这意味着将耗费更多的时间
5、索引失效的情况:
　① Not Null/Null 如果某列建立索引,当进行Select * from emp where depto is not null/is null。 则会是索引失效。
　② 索引列上不要使用函数,SELECT Col FROM tbl WHERE substr(name ,1 ,3 ) = 'ABC' 
或者SELECT Col FROM tbl WHERE name LIKE '%ABC%' 而SELECT Col FROM tbl WHERE name LIKE 'ABC%' 会使用索引。
　③ 索引列上不能进行计算SELECT Col FROM tbl WHERE col / 10 > 10 则会使索引失效，应该改成
SELECT Col FROM tbl WHERE col > 10 * 10
　④ 索引列上不要使用NOT （ != 、 <> ）如:SELECT Col FROM tbl WHERE col ! = 10 
应该 改成：SELECT Col FROM tbl WHERE col > 10 OR col < 10 。
6、用UNION替换OR(适用于索引列)
　 union:是将两个查询的结果集进行追加在一起，它不会引起列的变化。 由于是追加操作，需要两个结果集的列数应该是相关的，
并且相应列的数据类型也应该相当的。union 返回两个结果集，同时将两个结果集重复的项进行消除。 如果不进行消除，用UNOIN ALL.
通常情况下, 用UNION替换WHERE子句中的OR将会起到较好的效果. 对索引列使用OR将造成全表扫描. 注意, 以上规则只针对多个索引列有效. 
如果有column没有被索引, 查询效率可能会因为你没有选择OR而降低. 在下面的例子中, LOC_ID 和REGION上都建有索引.

　　高效:
　　SELECT LOC_ID , LOC_DESC , REGION
　　FROM LOCATION
　　WHERE LOC_ID = 10
　　UNION
　　SELECT LOC_ID , LOC_DESC , REGION
　　FROM LOCATION
　　WHERE REGION = “MELBOURNE”

　　低效:
　　SELECT LOC_ID , LOC_DESC , REGION
　　FROM LOCATION
　　WHERE LOC_ID = 10 OR REGION = “MELBOURNE”
　　如果你坚持要用OR, 那就需要返回记录最少的索引列写在最前面.
7. 用EXISTS替代IN、用NOT EXISTS替代NOT IN
在许多基于基础表的查询中, 为了满足一个条件, 往往需要对另一个表进行联接. 在这种情况下, 使用EXISTS(或NOT EXISTS)通常将提高查询的效率. 
在子查询中, NOT IN子句将执行一个内部的排序和合并. 无论在哪种情况下, NOT IN都是最低效的(因为它对子查询中的表执行了一个全表遍历). 
为了避免使用NOT IN, 我们可以把它改写成外连接(Outer Joins)或NOT EXISTS.
例子：
高效: SELECT * FROM EMP (基础表) WHERE EMPNO > 0 AND EXISTS (SELECT ‘X’ FROM DEPT WHERE DEPT.DEPTNO = EMP.DEPTNO AND LOC = ‘MELB’)
低效: SELECT * FROM EMP (基础表) WHERE EMPNO > 0 AND DEPTNO IN(SELECT DEPTNO FROM DEPT WHERE LOC = ‘MELB’)



---
-- table date control  dml
---
---insert 
insert into table_name_new select * from table_name_old 
insert into table_name_new(column1,column2...) select column1,column2... from table_name_old
insert into test(id, time, test, num) values ('1', sysdate, 'test', '12.1');
insert into test(id, time, test, num) values ('3', sysdate, 'test3', '12.2');
insert into test(id, time, test, num) 
values ('2', to_date('1000-12-12 22:22:22','yyyy-mm-dd hh24:mi:ss'), 'test', '12.1');
insert into test2 values('1212', '1', 'name1');
--update
update  test set pwd=md5('cc'||id||md5('cc'||id||'qwer')) where id='admin';
update test
set(id,test,value)=(select 'no.'||rownum newid,num,value from test where 1=1 and id='1')
where id='1';
select * from test;
--page query
select * from ( select t.*,rownum rowno from ( 
        select * from tb_user_msg order by time
 ) t where rownum < 10 ) where rowno > 2
--delete
delete from test where 1=1 and id = 'aaa';
--drop table 
truncate table test;
--time to_char
select t.*,to_char(t.time, 'yyyy-mm-dd hh24:mi:ss') tochar from test t;
--count group having 
select tid, count(tid)  from 
(
select t1.*,t2.id ttid,t2.tid,t2.name from test t1, test2 t2
where 1=1
and t1.id>0 
and t1.id=t2.tid(+)
) t 
where 1=1
group by tid
having count(tid) >= 0

--join
select t1.*,count(t2.tid) from test t1 
left join test2 t2
on t1.id=t2.tid
where 1=1
and t1.id>0  
group by t2.tid

--every row group one line
select * from (
    select  row_number() over ( partition by t.test order by time desc) rn
    ,t.* 
    from test t
) tt where 1=1
and rn=1;


--like instr
select * from test t where INSTR('唐飞',T.NAME)>0 or t.name like '%aa%'

--with temp table view? 查询完毕直接清除
with 
temptable as (select * from test)
,temptable2 as (select * from test)
select * from temptable,temptable2 whre a=1;
 
--exists 
select * from t1 where exists(select 1 from t2 where t1.a=t2.a) ;


1.会话级别临时表
会话级临时表是指临时表中的数据只在会话生命周期之中存在，当用户退出会话结束的时候，Oracle自动清除临时表中数据。
create global temporary table aaa(id number) on commit oreserve rows;
create global temporary table tempp on commit oreserve rows as select * from test;

insert into aaa values(100);
select * from aaa;
这是当你在打开另一个会话窗口的时候再次查询，表内的数据就查询不到了。
2.事务级别的临时表
create global temporary table bbb(id number) on commit delete rows;
insert into bbb values(200);

--多行拼接转一列
wm_concat
select wm_concat(colname) from student;

--行列转换
select name
,sum(decode(age, '16', num, null)) age16
,sum(decode(age, '17', num, null)) age17
,sum(decode(age, '18', num, null)) age18
from student;


---
---  function  trigger  job  procedure seq  md5 
---

create or replace trigger tr_info 
   before insert  
   on info 
   for each row  
begin
   update  info set about='1' where id like '%'||to_number(to_char(sysdate,'ss'))||'%' ;  
   update  info set about='0' where id like '%'||to_number(to_char(sysdate,'mi'))||'%' ;  
end; 


--more in plsql.sql
create or replace procedure p_createroomtest(cc in integer) as
i integer;
begin
  i := cc;     
  while i > 0 loop
  begin
    insert into   kfgl_fj(id,roomnum,roomtype,curpeople,roomstat,stationid) values(seq_test.nextval, 't-' || seq_test1.nextval,'43eb189e-a2be-4538-8276-94bc27c2a2b1','0','0','5103211993' ) ;

    i:= i - 1;
  end;
  end loop;

end p_createroomtest; 


--do procedure
begin
  p_createroomtest(800);
  commit;
end;


create sequence seq_file_down_up
minvalue 1
maxvalue 99999999
start with 1
increment by 1
cache 20;

--sequece
insert into info(id,userid) values(seq_info.nextval, 'test1');
 


--job 
var job1 number; 
begin 
  dbms_job.submit(:job1,'p_job1_test;',sysdate,'sysdate+1/1440'); 
  commit; 
end; 

begin 
  dbms_job.run(:job1); 
end; 





---
---functions  of system 
---

--fill to length
select 'scjs' || lpad(seq_t_contract_three.nextval,3, '0') from dual 

-- nvl nvl2 case when
select 
 nvl(t.id,'id is null') idnull
,nvl2(t.id,'not null','id is null') idnull
,(case when t.id='1' then 'ê¡¹«ëÿ1' when t.id='2' then 'ê¡¹«ëÿ2' else '·ö¹«ëÿ' end) name
 from test t;

--self function 
create or replace function file_size(n in varchar2) return varchar2 is retval varchar2(32);
begin
 retval := '';
 select
(case
when n>1024*1024*1024*1024 then trunc(n*10/1024/1024/1024/1024)/10||'tb'
when n>1024*1024*1024 then trunc(n*10/1024/1024/1024)/10||'gb'
when n>1024*1024 then trunc(n*10/1024/1024)/10||'mb'
when n>1024 then trunc(n*10/1024)/10||'kb'
else n||'b' 
  end) res  into retval
from dual  ;
 return retval;
end;

-- dbms_obfuscation_toolkit.md5
create or replace function md5(passwd in varchar2) return varchar2 is retval varchar2(32);
begin
 retval := lower(utl_raw.cast_to_raw( dbms_obfuscation_toolkit.md5(input_string => passwd)) );
 return retval;
end;

select md5('123456') from  dual;
select greatest('2', '3', 1'') from dual;   --math.max
--random
select  dbms_random.value(1,100) from dual;

FLOOR——对给定的数字取整数位
SQL> select floor(2345.67) from dual;
FLOOR(2345.67)
--------------
2345
CEIL-- 返回大于或等于给出数字的最小整数
SQL> select ceil(3.1415927) from dual;

CEIL(3.1415927)
---------------
              4
ROUND——按照指定的精度进行四舍五入
select * from round(100 / 200, 4) * 100 || '%' from dual;
------------------
            3.1416%
TRUNC——按照指定的精度进行截取一个数
SQL> select trunc(3.1415926,4) from dual;
TRUNC(3.1415926,4)



--time date chat string 
insert into test values('0002', to_date('1000-12-12','yyyy-mm-dd hh24:mi:ss') );
select  to_char(time, 'yyyy-mm-dd hh24:mi:ss' ), id  from test;
select substr(to_char(systimestamp, 'yyyy-mm-dd hh24:mi:ss:ff'), 0, 23 ) from dual; --ºáãë œøè¡
select  to_char(  to_date('1000-12-12','yyyy-mm-dd hh24:mi:ss'), 'yyyy-mm-dd hh24:mi:ss') from dual
--month + 1
select to_char(add_months(trunc(sysdate),1),'yyyy-mm') from dual;
select  sysdate,sysdate - interval '7' minute  from dual
select  sysdate - interval '7' hour  from dual
select  sysdate - interval '7' day  from dual
select  sysdate,sysdate - interval '7' month from dual
select  sysdate,sysdate - interval '7' year   from dual
select  sysdate,sysdate - 8 *interval '2' hour   from dual




数据结构转换
to_number()
to_char()

