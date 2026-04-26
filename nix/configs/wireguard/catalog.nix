{
  defaultProfile = "wg-xafmcp";

  activeDir = "/persistent/wireguard/active";

  profiles = {
    "wg-nqrvma" = {
      autostart = false;
      active = "slot-a";
      candidates = {
        "slot-a" = {
          sopsFile = ../../../secrets/common/wireguard/items/prtycgdmzvnzocwc.yaml;
          runtimePath = "/run/wireguard/pool/wg-nqrvma/slot-a.conf";
        };
        "slot-b" = {
          sopsFile = ../../../secrets/common/wireguard/items/lppebotqikwmfgoh.yaml;
          runtimePath = "/run/wireguard/pool/wg-nqrvma/slot-b.conf";
        };
      };
    };

    "wg-vdrkye" = {
      autostart = false;
      active = "slot-a";
      candidates = {
        "slot-a" = {
          sopsFile = ../../../secrets/common/wireguard/items/hgfofqaamdmngwak.yaml;
          runtimePath = "/run/wireguard/pool/wg-vdrkye/slot-a.conf";
        };
        "slot-b" = {
          sopsFile = ../../../secrets/common/wireguard/items/ysjtwussvvxuaclk.yaml;
          runtimePath = "/run/wireguard/pool/wg-vdrkye/slot-b.conf";
        };
      };
    };

    "wg-xafmcp" = {
      autostart = true;
      active = "slot-a";
      candidates = {
        "slot-a" = {
          sopsFile = ../../../secrets/common/wireguard/items/uvjlkndcgbbcivoi.yaml;
          runtimePath = "/run/wireguard/pool/wg-xafmcp/slot-a.conf";
        };
        "slot-b" = {
          sopsFile = ../../../secrets/common/wireguard/items/jhzjidvfubsyfnyr.yaml;
          runtimePath = "/run/wireguard/pool/wg-xafmcp/slot-b.conf";
        };
        "slot-c" = {
          sopsFile = ../../../secrets/common/wireguard/items/zzskvbulmkhmfzdd.yaml;
          runtimePath = "/run/wireguard/pool/wg-xafmcp/slot-c.conf";
        };
        "slot-d" = {
          sopsFile = ../../../secrets/common/wireguard/items/kaihdmbcqrzfyxfn.yaml;
          runtimePath = "/run/wireguard/pool/wg-xafmcp/slot-d.conf";
        };
        "slot-e" = {
          sopsFile = ../../../secrets/common/wireguard/items/wrhdefajjjsjmnuc.yaml;
          runtimePath = "/run/wireguard/pool/wg-xafmcp/slot-e.conf";
        };
      };
    };

    "wg-hzplwt" = {
      autostart = false;
      active = "slot-e";
      candidates = {
        "slot-a" = {
          sopsFile = ../../../secrets/common/wireguard/items/bfrkxdjgsdossmpb.yaml;
          runtimePath = "/run/wireguard/pool/wg-hzplwt/slot-a.conf";
        };
        "slot-b" = {
          sopsFile = ../../../secrets/common/wireguard/items/wkxjlseajfjcudzd.yaml;
          runtimePath = "/run/wireguard/pool/wg-hzplwt/slot-b.conf";
        };
        "slot-c" = {
          sopsFile = ../../../secrets/common/wireguard/items/urztvvbxycdskprh.yaml;
          runtimePath = "/run/wireguard/pool/wg-hzplwt/slot-c.conf";
        };
        "slot-d" = {
          sopsFile = ../../../secrets/common/wireguard/items/rudxykwfxldnphqz.yaml;
          runtimePath = "/run/wireguard/pool/wg-hzplwt/slot-d.conf";
        };
        "slot-e" = {
          sopsFile = ../../../secrets/common/wireguard/items/xwcfkpyqipxqmlch.yaml;
          runtimePath = "/run/wireguard/pool/wg-hzplwt/slot-e.conf";
        };
        "slot-f" = {
          sopsFile = ../../../secrets/common/wireguard/items/pbwnslcgwfykxblx.yaml;
          runtimePath = "/run/wireguard/pool/wg-hzplwt/slot-f.conf";
        };
        "slot-g" = {
          sopsFile = ../../../secrets/common/wireguard/items/hweytyaxffzpawnj.yaml;
          runtimePath = "/run/wireguard/pool/wg-hzplwt/slot-g.conf";
        };
        "slot-h" = {
          sopsFile = ../../../secrets/common/wireguard/items/qczmrkvrwjtrmddb.yaml;
          runtimePath = "/run/wireguard/pool/wg-hzplwt/slot-h.conf";
        };
        "slot-i" = {
          sopsFile = ../../../secrets/common/wireguard/items/oejqlhzfsihowshb.yaml;
          runtimePath = "/run/wireguard/pool/wg-hzplwt/slot-i.conf";
        };
      };
    };

    "wg-kqsjdn" = {
      autostart = false;
      active = "slot-a";
      candidates = {
        "slot-a" = {
          sopsFile = ../../../secrets/common/wireguard/items/plfovytebwjvfvke.yaml;
          runtimePath = "/run/wireguard/pool/wg-kqsjdn/slot-a.conf";
        };
        "slot-b" = {
          sopsFile = ../../../secrets/common/wireguard/items/szpauwcvdgdqpvvn.yaml;
          runtimePath = "/run/wireguard/pool/wg-kqsjdn/slot-b.conf";
        };
        "slot-c" = {
          sopsFile = ../../../secrets/common/wireguard/items/irpdsjcwyecasnig.yaml;
          runtimePath = "/run/wireguard/pool/wg-kqsjdn/slot-c.conf";
        };
        "slot-d" = {
          sopsFile = ../../../secrets/common/wireguard/items/rnmbijoasppvtqla.yaml;
          runtimePath = "/run/wireguard/pool/wg-kqsjdn/slot-d.conf";
        };
        "slot-e" = {
          sopsFile = ../../../secrets/common/wireguard/items/bwzisukfmmreokak.yaml;
          runtimePath = "/run/wireguard/pool/wg-kqsjdn/slot-e.conf";
        };
        "slot-f" = {
          sopsFile = ../../../secrets/common/wireguard/items/segerdajclgaywgt.yaml;
          runtimePath = "/run/wireguard/pool/wg-kqsjdn/slot-f.conf";
        };
        "slot-g" = {
          sopsFile = ../../../secrets/common/wireguard/items/ohakogxecilbyvvs.yaml;
          runtimePath = "/run/wireguard/pool/wg-kqsjdn/slot-g.conf";
        };
        "slot-h" = {
          sopsFile = ../../../secrets/common/wireguard/items/dchemuvzoicaafff.yaml;
          runtimePath = "/run/wireguard/pool/wg-kqsjdn/slot-h.conf";
        };
        "slot-i" = {
          sopsFile = ../../../secrets/common/wireguard/items/ogefwebpkrzqgrtn.yaml;
          runtimePath = "/run/wireguard/pool/wg-kqsjdn/slot-i.conf";
        };
        "slot-j" = {
          sopsFile = ../../../secrets/common/wireguard/items/yvkrknljdqjwlzao.yaml;
          runtimePath = "/run/wireguard/pool/wg-kqsjdn/slot-j.conf";
        };
        "slot-k" = {
          sopsFile = ../../../secrets/common/wireguard/items/yjdmyvehcyzhhpww.yaml;
          runtimePath = "/run/wireguard/pool/wg-kqsjdn/slot-k.conf";
        };
      };
    };

  };
}
