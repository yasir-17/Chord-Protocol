use "collections"
use "time"
use "random"

class NumberGenerator is TimerNotify
  let _env: Env
  var _counter: U64
  var _limit: U64 = 4
  var _main: Main

  new iso create(env: Env, limit: U64, main: Main) =>
    _counter = 0
    _env = env
    _limit = limit
    _main = main

  fun ref _next(): String =>
    _counter = _counter + 1
    _main.send_message(_counter)
    _counter.string()

  fun ref apply(timer: Timer, count: U64): Bool =>
    if _counter >= _limit then 
      return false  
    end

    _env.out.print(_next())
    true

actor Node
    let _env: Env
    let id: U64
    var predecessor_id: U64
    var successor_id: U64
    let main: Main 
    var finger_table: Map[U64, Node] val 
    var finger_keys : Array[U64] val
    
    new create(id': U64, main': Main, env: Env) =>
        _env = env
        main = main'
        id = id'
        predecessor_id = 0
        successor_id = 0
        finger_table = Map[U64, Node]
        finger_keys = Array[U64]
        
    be set_successor(succ: U64) =>
        successor_id = succ
    
    be set_predecessor(pred: U64) =>
        predecessor_id = pred
    
    fun get_id() =>
        id

        
    be set_finger_table(finger_table': Map[U64, Node tag] val, finger_keys': Array[U64] val) =>
        finger_table = finger_table'
        finger_keys = finger_keys'
        try 
            this.set_successor(finger_keys(0)?)
        end

    be send_request(key_id: U64, hops: U64) => 
        // If my predecessor is wrapped around and key is less than current node
        if (predecessor_id > id) and (key_id <= id) then
            main.notify_hops(hops)
            return
        end

        // If the key_id belongs to the current node, update
        if (predecessor_id < key_id) and (key_id <= id) then
            main.notify_hops(hops)
        
        // Else if it belongs to the current and neighbor
        else if (id < key_id) and (key_id <= successor_id) then
            main.notify_hops(hops + 1)
        
        else
            try
                // If the value is larger than the largest successor, delegate the work to that node
                var largest_predecessor_id: U64 = finger_keys(finger_keys.size() - 1)?
                var largest_predecessor: Node = finger_table(largest_predecessor_id)?
            
                // Find the largest predecessor whose id is lesser than key_id,
                // delegate the work to the predecessor node
                for i in Range(1, finger_table.size()) do
                    let curr_node_id = finger_keys(i - 1)?
                    let next_node_id = finger_keys(i)?

                    // In case of wrap-around, compare if the key falls between the left and right
                    // If it does, give the key to right, else keep iterating
                    if curr_node_id > next_node_id then 
                        if (key_id < next_node_id) or (key_id >= curr_node_id) then
                            largest_predecessor = finger_table(curr_node_id)?
                            break
                        end
                    end

                    if (curr_node_id <= key_id) and (key_id < next_node_id) then
                        largest_predecessor = finger_table(curr_node_id)?
                        break
                    end
                end
                largest_predecessor.send_request(key_id, 1 + hops)
            else 
                _env.out.print("Error in sending request")
            end
        end
    end

actor Main
    let _env: Env
    var num_nodes: U64 = 0
    var num_requests: U64 = 0
    var network_size: U64 = 0
    var finger_table_size: U64 = 0
    let nodes: Map[U64, Node] = Map[U64, Node]
    let picked: Set[USize] = Set[USize]
    var completed_requests: U64 = 0
    var total_hops: U64 = 0
    var messages: Array[U64] = []

    new create(env: Env) =>
        _env = env
        try
            if env.args.size() != 3 then
                error    
            end
            num_nodes = env.args(1)?.u64()?
            num_requests = env.args(2)?.u64()?
            setup_chord_network()
        else
            _env.out.print("Error in parsing command line arguments")
        end

    fun ref create_network() =>
        let interval: F64 = network_size.f64() / num_nodes.f64()
        
        var i: U64 = 0
        while i < num_nodes do
            let position = (i.f64() * interval).round().u64()
            let new_node = Node(position, this, _env)

            nodes(position) = new_node

            if i != 0 then 
                var pre: U64 = ((i.f64() - 1) * interval).round().u64()
                try nodes(position)?.set_predecessor(pre) end
            end


            i = i + 1
        end
        var pred_of_first = ((i.f64() - 1) * interval).round().u64()

        try nodes(0)?.set_predecessor(pred_of_first) end


        _env.out.print("Finger table size: " + finger_table_size.string())

        for nodeId in nodes.keys() do
            let finger_table: Map[U64, Node] iso = Map[U64, Node]
            let finger_table_keys: Array[U64] iso = Array[U64]
            

            var j: U64 = 0
            while j < finger_table_size do
                let jump = U64(1) << j  // 2^j
                let targetId = (nodeId + jump) % network_size
                
                let successor_id = find_successor(targetId)

                try
                    if not finger_table.contains(successor_id) then 
                        finger_table_keys.push(successor_id)
                    end

                    finger_table(successor_id) = nodes(successor_id)?
                end
                
                j = j + 1
            end

            try
                nodes(nodeId)?.set_finger_table(consume finger_table, consume finger_table_keys)
            end
        end


    fun get_max(a: U64, b: U64): U64 =>
        if a > b 
            then a else b 
        end

    fun ref get_network_size(): U64 =>
        var size: U64 = 1
        var count: U64 = 0
        let maxlimit: U64 = num_nodes//gemax(num_nodes, num_requests)
        while size <= maxlimit do
            size = size * 2
            count = count + 1
        end
        finger_table_size = count
        size


    fun ref find_successor(id: U64): U64 =>
        var successor_id = id
        
        while not nodes.contains(successor_id) do
            successor_id = (successor_id + 1) % network_size
        end
        
        successor_id

    
    fun ref generate(count: USize, min: U64, max: U64): Array[U64] =>
        
        let range = max - (min + 1)
        let rand = Rand(Time.nanos())

        if count > range.usize() then
            return Array[U64]
        end

        let numbers = Array[U64](range.usize())
        var i: U64 = min
        while i <= max do
            numbers.push(i)
            i = i + 1
        end

        let result = Array[U64](count)
        var remaining = range.usize()
        try
            while result.size() < count do
                let index = rand.int(remaining.u64()).usize()
                result.push(numbers(index)?) 

                numbers(index)? = numbers(remaining - 1)?
                remaining = remaining - 1
            end
        end
        
        result


    be notify_hops(hops': U64) =>
        total_hops = total_hops + hops'
        completed_requests = completed_requests + 1
        _env.out.print("Hop notified: " + completed_requests.string())
        if completed_requests >= (num_requests*num_nodes) then
            // Calculate Average
            let average: F64 = total_hops.f64() / completed_requests.f64()
            _env.out.print("Average hops is: " + average.string())
        end
        

    fun ref setup_chord_network() =>
        network_size = get_network_size()
        _env.out.print("* Building the network of size: * " + network_size.string())

        create_network()

        messages = generate(num_requests.usize(), 0, network_size)

        let timers = Timers
        let timer = Timer(NumberGenerator(_env, messages.size().u64(), this), 0, 1_000_000_000)
        timers(consume timer)

    be send_message(index: U64) => 
        try
            _env.out.print("sending messsage: " + messages((index-1).usize())?.u64().string())
        end

        try 
            for nodeId in nodes.keys() do
                nodes(nodeId)?.send_request(messages((index-1).usize())?.u64(), 0)
            end
        end
