{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: {
  # 1. FIXED: Import the standard default Home Manager module
  imports = [inputs.nvf.homeManagerModules.default];

  # Global lazygit for your standard terminal
  programs.lazygit = {
    enable = true;
    settings = {
      gui.theme = {
        lightTheme = false;
      };
    };
  };

  # Use lib.mkMerge or standard definition (removed mkForce so internal nvf defaults can blend properly)
  programs.nvf = lib.mkForce {
    enable = true;
    enableManpages = true;
    settings.vim = {
      clipboard = {
        enable = true;
        registers = "unnamedplus";
        providers.wl-copy.enable = true;
      };
      viAlias = true;
      vimAlias = true;

      # Expose lazygit to Neovim's sandbox environment
      extraPackages = with pkgs; [
        lazygit
      ];

      # --- MAXED OUT LANGUAGE & LSP STACK ---
      languages = {
        enableLSP = true;
        enableTreesitter = true;
        enableFormat = true;
        enableExtraDiagnostics = true;

        # Enable all desired language ecosystems (LSP, formatters, and parsers included automatically)
        nix.enable = true;
        bash.enable = true;
        python.enable = true;
        ts.enable = true;
        rust.enable = true;
        go.enable = true;
        lua.enable = true;
        markdown.enable = true;
        html.enable = true;
        css.enable = true;
        sql.enable = true;
        json.enable = true;
        yaml.enable = true;
      };

      # Core LSP UI & Autocompletion
      lsp = {
        enable = true;
        formatOnSave = true;
        lightbulb.enable = true;
        trouble.enable = true;
        lspSignature.enable = true;
      };
      autocomplete.nvim-cmp.enable = true;
      snippets.luasnip.enable = true;
      # --------------------------------------

      # --- YOUR CUSTOM UI & TOOLS ---
      # Use Neo-tree (and explicitly disable nvimTree to prevent conflicting file explorers)
      filetree.neo-tree.enable = true;
      filetree.nvimTree.enable = false;

      terminal.toggleterm = {
        enable = true;
        lazygit = {
          enable = true;
          mappings.open = "<leader>lg";
        };
      };

      # Your Custom Keymaps
      keymaps = [
        {
          key = "<leader>e";
          mode = "n";
          silent = true;
          action = ":Neotree toggle<CR>";
          desc = "Toggle Neo-tree file explorer";
        }
        {
          key = "<leader>m";
          mode = "n";
          silent = true;
          action = ":make<CR>";
          desc = "Run make";
        }
        {
          key = "<leader>l";
          mode = ["n" "x"];
          silent = true;
          action = "<cmd>cnext<CR>";
          desc = "Next quickfix item";
        }
      ];

      statusline.lualine = {
        enable = true;
        theme = "auto";
      };
      theme = {
        enable = true;
        name = "base16";
        transparent = true;
        base16-colors = {
          inherit
            (config.lib.stylix.colors.withHashtag)
            base00
            base01
            base02
            base03
            base04
            base05
            base06
            base07
            base08
            base09
            base0A
            base0B
            base0C
            base0D
            base0E
            base0F
            ;
        };
      };
      # Additional quality-of-life utilities to round out the maxed-out IDE feel
      telescope.enable = true;
      binds.whichKey.enable = true;
      git.gitsigns.enable = true;
    };
  };
}
