import lldb


def lldb_cmd(debugger, cmd):
    interpreter = debugger.GetCommandInterpreter()
    rst = lldb.SBCommandReturnObject()
    interpreter.HandleCommand(cmd, rst)
    return rst.GetOutput()


def get_hex(s):
    return int(s[s.find("0x") :].strip(), base=16)

def get_first_hex(line):
    return int(line[line.find("0x") + 2 : line.find(":")], base=16)


def get_offset_around(debugger, addr):
    cnt = 0
    rst = 0
    for offset in range(-1, -90, -1):
        for line in lldb_cmd(debugger, f"dis -Ai386 -c50 -s  {addr + offset}").split("\n"):
            if not line:
                continue
            line_addr = get_first_hex(line)
            if line_addr == addr:
                cnt += 1
                rst = offset
                if cnt == 5:
                    return offset
                break
    return rst


def disassemble_around_address(debugger, command, result, internal_dict):
    output = []
    rip = get_hex(lldb_cmd(debugger, "reg r rip"))
    cs = get_hex(lldb_cmd(debugger, "reg r cs"))
    cr0 = get_hex(lldb_cmd(debugger, "reg r cr0"))
    if cr0 & 1:
        addr = rip
    else:
        addr = cs * 16 + rip
    offset = get_offset_around(debugger, addr)
    dis_out = lldb_cmd(debugger, f"dis -c 10 -b -Ai386 -s {addr + offset}")
    
    for line in dis_out.split("\n"):
        if not line:
            continue
        if get_first_hex(line) == addr:
            output.append("->" + line)
            continue
        output.append(line)
            
    output = "\n".join(output)
    result.AppendMessage(output)

def __lldb_init_module(debugger, internal_dict):
    debugger.HandleCommand(
        "command script add -f lldb_helper.disassemble_around_address d86"
    )
