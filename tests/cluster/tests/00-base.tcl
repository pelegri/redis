# Check the basic monitoring and failover capabilities.

source "../tests/includes/init-tests.tcl"

if {$::simulate_error} {
    test "This test will fail" {
        fail "Simulated error"
    }
}

test "Cluster nodes are reachable" {
    foreach_redis_id id {
        # Every node should just know itself.
        assert {[R $id ping] eq {PONG}}
    }
}

test "Different nodes have different IDs" {
    set ids {}
    set numnodes 0
    foreach_redis_id id {
        incr numnodes
        # Every node should just know itself.
        set nodeid [dict get [get_myself $id] id]
        assert {$nodeid ne {}}
        lappend ids $nodeid
    }
    set numids [llength [lsort -unique $ids]]
    assert {$numids == $numnodes}
}

test "Check if nodes auto-discovery works" {
    # Join node 0 with 1, 1 with 2, ... and so forth.
    # If auto-discovery works all nodes will know every other node
    # eventually.
    set ids {}
    foreach_redis_id id {lappend ids $id}
    for {set j 0} {$j < [expr [llength $ids]-1]} {incr j} {
        set a [lindex $ids $j]
        set b [lindex $ids [expr $j+1]]
        set b_port [get_instance_attrib redis $b port]
        R $a cluster meet 127.0.0.1 $b_port
    }

    foreach_redis_id id {
        wait_for_condition 1000 50 {
            [llength [get_cluster_nodes $id]] == [llength $ids]
        } else {
            fail "Cluster failed to join into a full mesh."
        }
    }
}
