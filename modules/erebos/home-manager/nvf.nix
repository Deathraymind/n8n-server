{
  inputs,
  pkgs,
  lib,
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

      # Additional quality-of-life utilities to round out the maxed-out IDE feel
      telescope.enable = true;
      binds.whichKey.enable = true;
      git.gitsigns.enable = true;
    };
  };
}
