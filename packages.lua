return {
  ["skid"] = {
    name="poo",
    files={["main/bob.lua"]="/usr/bin"}
  },
  ["linknet"] = {
    name="linknet",
    files={["main/linknets/linknet.lua"]="/usr/bin"}
  },
  ["protnet"] = {
    name="protnet",
    files={["main/linknets/protnet.lua"]="/usr/bin"}
  },
  ["pm"] = {
    name="pm",
    files={["main/pm.lua"]="/usr/bin"}
  },
  ["shit"] = {
    name="shit lib",
    files={["main/shit.lua"]="/usr/lib"}
  },
  ["shiter"] = {
    name="shiter",
    files={["main/shiter.lua"]="/usr/bin"}
    depends={"shit"}
  }
}