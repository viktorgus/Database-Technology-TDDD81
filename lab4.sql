SET FOREIGN_KEY_CHECKS = 0;
drop table if exists Weekly_Schedule;
drop table if exists Year;
drop table if exists Day;
drop table if exists Route;
drop table if exists Destination;
drop table if exists Flight;
drop table if exists Reservation;
drop table if exists Booking;
drop table if exists Ticket;
drop table if exists Credit_Card;
drop table if exists Passenger;
drop table if exists PassengerToReservation;
drop table if exists Contact;
drop procedure if exists addDay;
drop procedure if exists addYear;
drop procedure if exists addFlight;
drop procedure if exists addRoute;
drop procedure if exists addDestination;
drop function if exists calculateFreeSeats;
drop function if exists calculatePrice;
drop trigger if exists generateTicket;
drop procedure if exists addReservation;
drop procedure if exists addPassenger;
drop procedure if exists addContact;
drop procedure if exists addPayment;
drop table if exists tempPassengers;
drop view if exists allFlights;
drop view if exists routenames;
SET FOREIGN_KEY_CHECKS = 1;

create table Weekly_Schedule(
id Integer AUTO_INCREMENT,
dep_time time not null,
route Integer not null,
day varchar(10) not null,
year Integer,
constraint pk_id
primary key (id)
);

create table Route(
id Integer AUTO_INCREMENT,
arrival varchar(3) not null,
departure varchar(3) not null,
routeprice double not null,
year Integer not null,
constraint pk_id
primary key (id)
);

create table Destination(
airport_code varchar(3),
name varchar(30),
country varchar(30),
constraint pk_code
primary key(airport_code)
);

create table Year(
year Integer,
profitfactor double not null,
constraint pk_year
primary key(year)
);

create table Day(
day varchar(10),
weekdayfactor double not null,
year Integer,
constraint pk_day
primary key(day,year)
);

create table Flight(
flightnumber Integer AUTO_INCREMENT,
weekly_flight_id Integer not null,
week Integer not null,
constraint pk_flight
primary key(flightnumber)
);

create table Reservation(
reservation_number Integer AUTO_INCREMENT,
flight Integer not null,
passengernumber Integer not null,
contact Integer,
constraint pk_reservation
primary key(reservation_number)
);

create table Booking(
reservation Integer,
contact Integer not null,
price Integer not null,
credit_card bigint not null,
constraint pk_booking
primary key(reservation)
);

create table Credit_Card(
creditcard_number bigint not null,
creditcard_holder VARCHAR(30) not null,
constraint pk_creditcard
primary key(creditcard_number)
);

CREATE TABLE PassengerToReservation(
passenger Integer,
reservation Integer,
constraint pk_pass_reserv
primary key(passenger, reservation)
);


CREATE TABLE Passenger(
passport_number Integer,
name VARCHAR(30),
constraint pk_passenger
primary key(passport_number)
);

CREATE TABLE Contact(
passport_number Integer,
phone BIGINT,
email VARCHAR(30),
constraint pk_contact
primary key(passport_number)
);

CREATE TABLE Ticket(
id Integer,
passenger Integer not null,
booking Integer,
constraint pk_ticket
primary key(id)
);

alter table Weekly_Schedule
add
foreign key (route) references Route(id),
add
foreign key (day,year) references Day(day,year),
add
foreign key (year) references Year(year);
 
alter table Route
add
foreign key (arrival) references Destination(airport_code),
add
foreign key (departure) references Destination(airport_code),
add
foreign key (year) references Year(year);

alter table Day
add
foreign key(year) references Year(year);

alter table Flight
add
foreign key (weekly_flight_id) references Weekly_Schedule(id);

alter table Reservation
add
foreign key (flight) references Flight(flightnumber),
add
foreign key (contact) references Contact(passport_number);

alter table Booking
add
foreign key (reservation) references Reservation(reservation_number),
add
foreign key (contact) references Contact(passport_number);

alter table Ticket
add
foreign key (passenger) references Passenger(passport_number),
add
foreign key (booking) references Booking(reservation);

alter table PassengerToReservation
add
foreign key (passenger) references Passenger(passport_number),
add
foreign key (reservation) references Reservation(reservation_number);

alter table Contact
add
foreign key (passport_number) references Passenger(passport_number);


DELIMITER //
CREATE PROCEDURE addYear
(IN year Integer, IN factor double)
BEGIN
  Insert into Year(year,profitfactor)
  values (year,factor);
END; 


CREATE PROCEDURE addDay
(IN year Integer, IN day varchar(10), IN factor double)
BEGIN
  Insert into Day(day,weekdayfactor,year)
  values (day,factor,year);
END; 


CREATE PROCEDURE addDestination
(IN airport_code varchar(3), IN name varchar(30),IN country varchar(30))
BEGIN
  Insert into Destination(airport_code,name,country)
  values (airport_code,name,country);
END; 


CREATE PROCEDURE addRoute
(IN departure_airport_code varchar(3), IN arrival_airport_code varchar(3),IN year Integer, IN routeprice double)
BEGIN
  Insert into Route(arrival,departure,routeprice,year)
  values (arrival_airport_code,departure_airport_code,routeprice,year);
END; 



CREATE PROCEDURE addFlight
(IN departure_airport_code varchar(3), IN arrival_airport_code varchar(3), 
IN routeyear Integer,IN day varchar(10),IN departure_time time)
BEGIN
declare routeid Integer;
declare scheduleid Integer;
declare weekiterator Integer;

  SET routeid = (select id from Route where arrival=arrival_airport_code and departure=departure_airport_code and year=routeyear);
  Insert into Weekly_Schedule(day,dep_time,route,year)
  values (day,departure_time,routeid,routeyear);
  SET scheduleid = LAST_INSERT_ID();
  SET weekiterator = 1;
  WHILE weekiterator <= 52 DO
    Insert into Flight(weekly_flight_id,week)
  values (scheduleid,weekiterator);
  SET weekiterator = weekiterator+1;
  END WHILE;
END; 

CREATE FUNCTION calculateFreeSeats
(flightnumber Integer)
RETURNS int
BEGIN
DECLARE tickets INT;
DECLARE seats_available INT;

select Count(*) into tickets from Reservation R inner join Ticket T on R.flight = flightnumber and T.Booking = R.reservation_number;
set seats_available = 40 - tickets;
RETURN seats_available;
END;

CREATE FUNCTION calculatePrice
(flightnumber Integer)
RETURNS double
BEGIN
DECLARE routeprice double;
DECLARE weekdayfactor double;
DECLARE profitfactor double;
DECLARE bookedpassengers int;
DECLARE weeklyflightid int;
DECLARE TotalPrice double;

set bookedpassengers = 40 - calculateFreeSeats(flightnumber);
select weekly_flight_id into weeklyflightid from Flight F where F.flightnumber = flightnumber;
select R.routeprice into routeprice from Route R, Weekly_Schedule S where R.id=S.route and S.id = weeklyflightid;
select Y.profitfactor into profitfactor from Year Y, Weekly_Schedule S where Y.year=S.year and S.id = weeklyflightid;
select D.weekdayfactor into weekdayfactor from Day D, Weekly_Schedule S where D.day=S.day and S.id = weeklyflightid;

set TotalPrice = routeprice * weekdayfactor * (bookedpassengers + 1)/40 * profitfactor;
set TotalPrice = Round(TotalPrice, 12);
RETURN TotalPrice;
END;


CREATE TRIGGER generateTicket
AFTER INSERT ON Booking FOR EACH ROW
BEGIN
DECLARE no_passengers int;
DECLARE loop_iterator int default 0;
Lock table tempPassengers write;
CREATE TEMPORARY TABLE tempPassengers as (Select passenger from PassengerToReservation where reservation=new.reservation);
SELECT count(*) into no_passengers from tempPassengers;

while loop_iterator < no_passengers DO
insert into Ticket (id,booking,passenger)
values(rand()*100000, NEW.reservation, (select passenger from tempPassengers Limit loop_iterator,1));
set loop_iterator = loop_iterator + 1;
end while;
unlock tables;
END;

CREATE PROCEDURE addReservation(In departure_airport_code varchar(3), In arrival_airport_code varchar(3), in year int, in week int, in day varchar(10),in dep_time time, in number_of_passengers int, out output_reservation_nr int)
BEGIN
declare route_id int;
declare weekly_schedule_id int;
declare flightid int;
declare flightexist int default 0;
declare reservationexist int default 0;
declare weekly_schedule_exist int default 0;
declare routexist int default 0;


select id into route_id from Route R where R.departure = departure_airport_code and R.arrival = arrival_airport_code and R.year = year;
select id into weekly_schedule_id from Weekly_Schedule W where W.route = route_id and W.day = day and W.dep_time = dep_time;
select flightnumber into flightid from Flight F where F.week = week and F.weekly_flight_id = weekly_schedule_id;


select count(*) into flightexist from Flight F where F.week = week and F.weekly_flight_id = weekly_schedule_id;
select count(*) into weekly_schedule_exist from Weekly_Schedule W where W.route = route_id and W.day = day and W.dep_time = dep_time;
select count(*) into routexist from Route where departure = departure_airport_code and arrival = arrival_airport_code;

if routexist=0  or weekly_schedule_exist = 0 or flightexist = 0 then
select 'There exist no flight for the given route, date and time' as 'Message';
else

IF number_of_passengers <= calculateFreeSeats(flightid) then
INSERT into Reservation (flight,passengernumber)
values (flightid,number_of_passengers);
set output_reservation_nr = LAST_INSERT_ID();
select 'OK result' as 'Message';
ELSE
set output_reservation_nr = null;
select 'There are not enough seats available on the chosen flight' as 'Message';
END IF;
END IF;
END;

CREATE PROCEDURE addPassenger(in reservation_nr Integer, in passport_number Integer,in name varchar(30))
BEGIN
declare passengerexists int;
declare checkreservation int default 0;
declare ispayed int default 0;
declare passengerammount int default 0;
declare reservationpassengers int;
select count(*) into ispayed from Booking where reservation=reservation_nr;
select count(*) into passengerexists from Passenger P where P.name = name and P.passport_number = passport_number;

if passengerexists = 0 then
insert into Passenger(name,passport_number) values(name,passport_number);
select 'OK result' as 'Message';
end if;

select count(*) into checkreservation from Reservation R where R.reservation_number = reservation_nr;
if checkreservation = 0 then
select 'The given reservation number does not exist' as 'Message';
else
if ispayed>0 then
Select 'The booking has already been payed and no futher passengers can be added' as 'Message';
ELSE

insert into PassengerToReservation(passenger, reservation) values(passport_number, reservation_nr);


select count(*) into passengerammount from PassengerToReservation P where P.reservation = reservation_nr;
select passengernumber into reservationpassengers from Reservation R where R.reservation_number=reservation_nr;

if passengerammount>reservationpassengers then
update Reservation 
set passengernumber=passengerammount
where reservation_number=reservation_nr;
END IF;
END IF;
END IF;
END;

CREATE PROCEDURE addContact(in reservation_nr Integer, in passport_number Integer, in email varchar(30), in phone BIGINT)
BEGIN
declare contactid int;
declare ispassenger int default 0;
declare reservationexist int default 0;
declare contactexist int default 0;
declare flightid int;
declare passengernum int;


select count(*) into ispassenger from PassengerToReservation P where P.passenger=passport_number and P.reservation = reservation_nr; 
select count(*) into reservationexist from Reservation where reservation_number=reservation_nr;
select count(*) into contactexist from Contact C where C.passport_number=passport_number;
select flight into flightid from Reservation where reservation_number=reservation_nr; 
select passengernumber into passengernum from Reservation where reservation_number=reservation_nr;
if reservationexist = 0 then
select 'The given reservation number does not exist' as 'Message';
else
if contactexist = 0 then
insert into Contact(passport_number,phone,email) values (passport_number, phone, email);
END IF;
if ispassenger = 0 then
select 'The person is not a passenger of the reservation' as 'Message';
else
update Reservation 
set contact = passport_number
where reservation_number=reservation_nr;
select 'OK result' as 'Message';
END IF;
END IF;
END;


create procedure addPayment(in reservation_nr Integer,in cardholder_name varchar(30),in credit_card_number BIGINT)
BEGIN
declare hasContact int default 0;
declare reservationexist int default 0;
declare ccexist int default 0;
declare no_passengers int default 0;
declare contactid int;
declare flightid int;

Drop Table if exists tempPassengers;
select count(*) into reservationexist from Reservation where reservation_number=reservation_nr;
select count(contact) into hasContact from Reservation where reservation_number=reservation_nr;
select passengernumber into no_passengers from Reservation where reservation_number = reservation_nr;
select contact into contactid from Reservation where reservation_number = reservation_nr;
select flight into flightid from Reservation where reservation_number = reservation_nr;

if reservationexist=0 then
select 'The given reservation number does not exist' as 'Message';
ELSE

if no_passengers > calculateFreeSeats(flightid) then
select 'There are not enough seats available on the flight anymore, deleting reservation' as 'Message';
Delete from PassengerToReservation where reservation=reservation_nr;
Delete from Reservation where reservation_number=reservation_nr;
ELSE
if hasContact = 0 then
Select 'The reservation has no contact yet' as 'Message';
ELSE
SELECT sleep(5);
select Count(*) into ccexist from Credit_Card C where C.creditcard_holder=cardholder_name and C.creditcard_number = credit_card_number;
if ccexist = 0 then
Insert into Credit_Card(creditcard_holder,creditcard_number) values (cardholder_name, credit_card_number);
END IF;
Insert into Booking(reservation, contact, price, credit_card) values(reservation_nr, contactid, no_passengers*calculatePrice(flightid),credit_card_number);

Select 'OK result' as 'Message';
END IF;
END IF;
END IF;
END;

Create view allFlights as Select 
departure.name departure_city_name, 
arrival.name destination_city_name,
W.dep_time departure_time, 
D.day departure_day, 
F.week departure_week, 
W.year departure_year,
calculateFreeSeats(F.flightnumber) nr_of_free_seats, 
calculatePrice(F.flightnumber) current_price_per_seat

From

Flight F,
Weekly_Schedule W,
Route R,
Destination arrival,
Destination departure,
Day D


Where

F.weekly_flight_id = W.id and
R.arrival = arrival.airport_code and
R.departure = departure.airport_code and
W.route = R.id and
D.day=W.day;


//
DELIMITER ;
