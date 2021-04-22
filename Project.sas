/*Project */
/*Importing excel files for sanity*/
proc import datafile="D:\1. SAS Project On Credit Card\1. SAS Project On Credit Card\Input files\Data.xls"
out=Customer_acquisition
dbms=xls
replace;
getnames=Yes;
sheet="Customer acquisition";
run;

proc import datafile="D:\1. SAS Project On Credit Card\1. SAS Project On Credit Card\Input files\Data.xls"
out=spend
dbms=xls
replace;
getnames=Yes;
sheet="spend";
run;

/*Importing txt file for Sanity checks*/
PROC IMPORT OUT= WORK.Customer_details 
            DATAFILE= "D:\1. SAS Project On Credit Card\1. SAS Project On Credit Card\Input files\Customer Details.txt" 
            DBMS=TAB REPLACE;
     GETNAMES=YES;
     DATAROW=2; 
RUN;


/*Importing csv file for Sanity checks*/
proc import datafile="D:\1. SAS Project On Credit Card\1. SAS Project On Credit Card\Input files\Repayment.csv"
out=repayment
dbms=dlm
replace;
getnames=Yes;
delimiter=",";
run;

/*Sanity check 1.*/
data sanity_email_check;
set customer_details;
where index(Email,"@") gt 0 and index(Email,".") gt 0;
run;

/*Sanity check 2.*/
data sanity_mobile_check;
set sanity_email_check;
if length(put(Mobile_number,10.))= 10;
run;

/*Sanity check 3.*/
data final_customer_details; *sanity_age_check is the latest file for customer_details now;
set sanity_mobile_check;
if age > 18;
run;

/*Sanity check 4.*/
data sanity_check4(drop=days_diff);
set repayment;
days_diff=intck('days',bill_generation_date,due_date) ;
if days_diff=15;
run;

/*Sanity check 5.*/
data sanity_check5;
set customer_acquisition;
if customer not in (" " ,"");
run;

/*Sanity check 6.*/
data sanity_check6;
set sanity_check5;
if lowcase(credit_card_product) in ("gold" ,"platimum","silver");
run;

/*Sanity check 7. ---------------*/ 
proc sql;
create table sanity_check7 as select c.customer from customer_acquisition c full join spend s 
on c.customer=s.customer and s.amount < c.limit;
quit;

/*Sanity check 8. ---------------*/
data blank final_spend;
set spend;
if missing (type) then output blank;
else output final_Spend;
run;

/*Sanity check 9. ---------------*/
data final_repayment(drop=y) invalid_data;
set repayment;
y=Bill_generation_date;
if  y > 19723 then output final_repayment ;
else if y < 19723 then output invalid_data;
run;

/*Sanity check 10.--------------------*/
proc sort data=Customer_details out=remove1 dupout=dup1 nodup;
by email;
run;

************ALL SANITY CHECKS ARE DONE******************;
/*final data sets
Final_Repaymentis latest file for repayment
final_customer_Details is the latest file for customer_details
Final_Spend is latest file for spend
sanity_check6 is final file for customer_acquisition
*/

/*Reports*/
/*1. Montly spend for each customer for all three years*/
Proc sql;
select customer, mon,sum(amount)as sum from (
select *, month(Month) as mon from spend) group by customer,mon;
quit;

/*2. Monthly repayment for each customer for all the three years*/
Proc sql;
select  customer, pay_mon,sum(Paid_amount)as sum from (
select *, month(pay_date) as pay_mon from sanity_check4) group by customer,pay_mon;
quit;

/*3. Category wise customer spending*/
proc sql;
select type,sum(amount) as sum from spend group by type;
quit;

/*4. Who are the highest spending 10 customers?*/
proc sql;
select customer, sum(amount) as sum from spend group by customer order by calculated sum desc;
quit;

/*5. */
proc sql;
create table spend_1 as select *,amount*.03 as min_pay_amount,month(month) as mnth, year(month) as yr from spend;
create table spend_2 as select customer,mnth,yr ,sum(min_pay_amount) as min_sum from spend_1 group by customer,mnth,yr;
quit;

proc sql;
create table repay_1 as select *,month(bill_generation_date) as mnth,year(bill_generation_date) as yr from repayment;
create table defaulters as select * ,rr.Paid_amount - ss.min_sum as diff from spend_2 ss full join repay_1 rr on 
ss.customer=rr.customer and ss.mnth=rr.mnth and ss.yr=rr.yr;
select * from defaulters dd where dd.diff <> .;
quit;

/*6. Cross tabulation of gender and age using formats*/
proc format lib=work;
value $genderfmt
'M'="Male"
'F'="Female";

value agefmt
0-<30 = "Young"
30-<60 = "Mid age"
others = "Old";
run;

proc freq data=customer_details ;
tables gender*age;
format gender $genderfmt. age agefmt.;
run;

/*7. Bar charts to show which age is spending more.*/
ods pdf file = "D:\1. SAS Project On Credit Card\1. SAS Project On Credit Card\bar_charts.pdf";
proc gchart data=final_customer_details;
vbar3d age/group=gender;
run;
ods pdf close;

/*8. Pie chart for credit card product type.*/
ods pdf file = "D:\1. SAS Project On Credit Card\1. SAS Project On Credit Card\pie_charts3d.pdf";
proc gchart data=sanity_check6;
pie3d credit_card_product;
run;
ods pdf close;

/*9. calculate product type wise mean spend amount for all the customers*/
proc means data=spend mean noprint nway;
var amount;
class type;
output out=amount_mean;
run;

ods pdf file = "D:\1. SAS Project On Credit Card\1. SAS Project On Credit Card\amount_mean.pdf";
proc print data=amount_mean;
run;
ods pdf close;

/*10.With the help of pie charts, show the total amount of three years on a pie chart and rename year as 2014,2015 and 2016. 
Explode all the three years one by one with the help of macros.*/
proc sql;
create table ro as select sum(Paid_Amount) as sum,year(pay_date)as x 
from final_repayment group by x;
quit;

%macro a;
proc sql;
select count(distinct x) into: n from ro;
select distinct x into: year separated by "@" from ro;
quit;
%do i=1 %to &n;
%let d=%scan(%sysfunc(compress(&year)),&i,"@");
title1 height=5 PCT font='Georgia'
'Year wise pie chart';
proc gchart data=ro;
pie3d x/sumvar=sum
noheading
woutline=1
slice=arrow value=arrow percent=arrow coutline=black explode=2014 2015 2016;
run; 
quit;
%end;
%mend a;
%a;

/*11. create a line graph depicting which credit card product has more number of customers*/
proc sql;
create table Q13 as select count(Customer) as count ,CREDIT_CARD_PRODUCT from Customer_acquisition group by CREDIT_CARD_PRODUCT;
quit;

ods pdf file = "D:\1. SAS Project On Credit Card\1. SAS Project On Credit Card\line_graph.pdf";
PROC SGPLOT DATA = Q13;    
SERIES X = CREDIT_CARD_PRODUCT Y = count /  LEGENDLABEL = 'Credit card vs total number of customers' MARKERS LINEATTRS = (THICKNESS = 2); 
XAXIS TYPE = DISCRETE GRID;    YAXIS LABEL = 'Number of customers' GRID VALUES = (10 TO 50 BY 5);  
TITLE 'Product type analysis'; 
RUN; 
ods pdf close;

/*12 highest and lowest five customers depending upon their total spend*/
proc sql;
create table go as select Customer_acquisition.customer,Customer_acquisition.CREDIT_CARD_PRODUCT,sum(spend.amount) as total_spend
from Customer_acquisition full join spend on Customer_acquisition.customer=spend.customer
group by Customer_acquisition.customer,Customer_acquisition.CREDIT_CARD_PRODUCT;
run;
title 'Highest and lowest five customers depending upon their total spend';
ods select extremeobs;

ods pdf file = "D:\1. SAS Project On Credit Card\1. SAS Project On Credit Card\univariate.pdf";
proc univariate data=go;
var total_Spend;
id customer;
run;
ods pdf close;

/*13, not able to import .accdb
proc pareto not found error is given in SAS 9.4/EG. 
Below is the sample code for pareto analysis.*/
proc freq data=a;
   tables issue / noprint out=b;
run;
title 'Analysis of customer issues';
symbol v=dot;
proc pareto data=b;
   vbar Issue / freq     = Count
                scale    = count
                interbar = 1.0
                last     = 'Miscellaneous'
                nlegend  = 'Total Issues'
                cframenleg;
run;


/*14. RYG*/
PROC FORMAT;
VALUE spend_color_fmt
LOW-<25000 = "RED"
25000-<40000 = "YELLOW"
40000-<60000 = "GREEN";
RUN; 

ods pdf file = "D:\1. SAS Project On Credit Card\1. SAS Project On Credit Card\ryg.pdf";
proc report data=spend;
DEFINE amount /
STYLE={BACKGROUND=spend_color_fmt.}; 
run;
ods pdf close;

/*15. Create a line graph to show the number of customers based on the product type for which they swipe the card*/
proc sql;
create table ko as select distinct type,count(customer) as customer_count from spend group by type;
quit;

ods pdf file = "D:\1. SAS Project On Credit Card\1. SAS Project On Credit Card\line_graph_cust_analysis.pdf";
PROC SGPLOT DATA = ko;    
SERIES X = TYPE Y = customer_count /  LEGENDLABEL = 'Customer wise type analysis' MARKERS LINEATTRS = (THICKNESS = 2); 
XAXIS TYPE = DISCRETE GRID;    YAXIS LABEL = 'Number of customers' GRID VALUES = (1 TO 300 BY 50);  
TITLE 'Product type analysis'; 
RUN;
ods pdf close;
