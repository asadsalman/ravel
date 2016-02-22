-------------------------------------------------------
-- add flow
-------------------------------------------------------

--DROP TABLE IF EXISTS ports CASCADE;
--CREATE UNLOGGED TABLE ports AS
--       SELECT switches.sid, t.nid, t.port
--       FROM switches, get_port(switches.sid) t ;
--CREATE INDEX ON ports(sid, nid);

CREATE OR REPLACE FUNCTION add_flow_wrapper ()
RETURNS TRIGGER
AS $$
    DECLARE
        sw_name varchar(16);
	sw_ip varchar(16);
	sw_dpid varchar(16);
        uh1 int;
        uh2 int;
        h1ip varchar(16);
	h1mac varchar(17);
        h2ip varchar(16);
	h2mac varchar(17);
        outport int;
        revoutport int;
    BEGIN
        -- arguments:
        -- host1 = NEW.pid
        -- host2 = NEW.nid
        -- switch_id = NEW.sid
        -- flow_id = NEW.fid

        -- get ports
        -- note: outport -> host1 (previous hop)
        --       revoutport -> host2 (next hop)
	SELECT port INTO outport FROM ports WHERE sid=NEW.sid and nid=NEW.nid;
	SELECT port INTO revoutport FROM ports WHERE sid=NEW.sid and nid=NEW.pid;
--        SELECT port INTO outport FROM get_port(NEW.sid) WHERE nid=NEW.pid;
--        SELECT port INTO revoutport FROM get_port(NEW.sid) WHERE nid=NEW.nid;

        -- get uids from flow id
        SELECT host1, host2 INTO uh1, uh2 FROM utm WHERE fid=NEW.fid;

	-- get switch info
	SELECT name, ip, dpid INTO sw_name, sw_ip, sw_dpid FROM switches WHERE sid=NEW.sid;

        -- get ip, mac addresses
        SELECT ip, mac INTO h1ip, h1mac FROM hosts WHERE hid IN (SELECT hid FROM uhosts WHERE u_hid=uh1);
        SELECT ip, mac INTO h2ip, h2mac FROM hosts WHERE hid IN (SELECT hid FROM uhosts WHERE u_hid=uh2);

        -- pass to python code
        PERFORM add_flow_fun(NEW.fid, sw_name, sw_ip, sw_dpid, h1ip, h1mac, h2ip, h2mac, outport, revoutport);
        return NEW;
    END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION add_flow_fun (flow_id integer,
       sw_name varchar(16), sw_ip varchar(16), sw_dpid varchar(16),
       h1ip varchar(16), h1mac varchar(17),
       h2ip varchar(16), h2mac varchar(17),
       outport integer, revoutport integer)
RETURNS integer
AS $$
import os
import sys
import time

if 'PYTHONPATH' in os.environ:
    sys.path = os.environ['PYTHONPATH'].split(':') + sys.path
sys.path.append('/home/croft1/src/cli-ravel')
import ravel.net

print 'In Install'
sw = ravel.net.Switch(sw_name, sw_ip, sw_dpid)
ravel.net.installFlow(flow_id, sw, h1ip, h1mac, h2ip, h2mac, outport, revoutport)

return 0
$$ LANGUAGE plpythonu VOLATILE SECURITY DEFINER;

--DROP TRIGGER add_flow_trigger ON cf;
CREATE TRIGGER add_flow_trigger
     AFTER INSERT ON cf
     FOR EACH ROW
   EXECUTE PROCEDURE add_flow_wrapper();



-------------------------------------------------------
-- del flow
-------------------------------------------------------
CREATE OR REPLACE FUNCTION del_flow_wrapper ()
RETURNS TRIGGER
AS $$
    DECLARE
        sw_name varchar(16);
	sw_ip varchar(16);
	sw_dpid varchar(16);
        uh1 int;
        uh2 int;
        h1ip varchar(16);
	h1mac varchar(17);
        h2ip varchar(16);
	h2mac varchar(17);
        outport int;
        revoutport int;
    BEGIN
        -- arguments:
        -- host1 = OLD.pid
        -- host2 = OLD.nid
        -- switch_id = OLD.sid
        -- flow_id = OLD.fid

        -- get ports
        -- note: outport -> host1 (previous hop)
        --       revoutport -> host2 (next hop)
	SELECT port INTO outport FROM ports WHERE sid=OLD.sid and nid=OLD.nid;
	SELECT port INTO revoutport FROM ports WHERE sid=OLD.sid and nid=OLD.pid;
--        SELECT port INTO outport FROM get_port(OLD.sid) WHERE nid=OLD.pid;
--        SELECT port INTO revoutport FROM get_port(OLD.sid) WHERE nid=OLD.nid;

        -- get uids from flow id
        SELECT host1, host2 INTO uh1, uh2 FROM rtm WHERE fid=OLD.fid;

	-- get switch info
	SELECT name, ip, dpid INTO sw_name, sw_ip, sw_dpid FROM switches WHERE sid=OLD.sid;

        -- get ip addresses
        SELECT ip, mac INTO h1ip, h2mac FROM hosts WHERE hid IN (SELECT hid FROM uhosts WHERE u_hid=uh1);
        SELECT ip, mac INTO h2ip, h2mac FROM hosts WHERE hid IN (SELECT hid FROM uhosts WHERE u_hid=uh2);

        -- pass to python code
        PERFORM del_flow_fun(OLD.fid, sw_name, sw_ip, sw_dpid, h1ip, h1mac, h2ip, h2mac, outport, revoutport);

        return OLD;
    END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION del_flow_fun (flow_id integer,
       sw_name varchar(16), sw_ip varchar(16), sw_dpid varchar(16),
       h1ip varchar(16), h1mac varchar(17),
       h2ip varchar(16), h2mac varchar(17),
       outport integer, revoutport integer)
RETURNS integer
AS $$
import os
import sys
import time

if 'PYTHONPATH' in os.environ:
    sys.path = os.environ['PYTHONPATH'].split(':') + sys.path
sys.path.append('/home/croft1/src/cli-ravel')

import ravel.net

print 'In Remove'
sw = ravel.net.Switch(sw_name, sw_ip, sw_dpid)
ravel.net.removeFlow(flow_id, sw, h1ip, h1mac, h2ip, h2mac, outport, revoutport)

return 0
$$ LANGUAGE plpythonu VOLATILE SECURITY DEFINER;


--DROP TRIGGER del_flow_trigger ON cf;
CREATE TRIGGER del_flow_trigger
     AFTER DELETE ON cf
     FOR EACH ROW
   EXECUTE PROCEDURE del_flow_wrapper();