{
  inputs,
  pkgs,
  ...
}: {
  imports = [inputs.nvf.homeManagerModules.default];

  programs.nvf = {
    enable = true;
    settings.vim = {
      viAlias = true;
      vimAlias = true;

      terminal.toggleterm = {
        enable = true;
        lazygit = {
          enable = true;
          mappings.open = "<leader>lg";
        };
      };

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
        }
        {
          key = "<leader>l";
          mode = ["n" "x"];
          silent = true;
          action = "<cmd>cnext<CR>";
        }
      ];

      statusline.lualine = {
        enable = true;
        theme = "auto";
      };
    };
  };
}
