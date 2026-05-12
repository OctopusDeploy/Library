import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// GitHub Pages for OctopusDeploy/Library is served at https://octopusdeploy.github.io/Library/
// The pr-review microsite lives at /pr-review/ under that base.
export default defineConfig({
  base: "/Library/pr-review/",
  plugins: [react()],
  build: {
    outDir: "dist",
    sourcemap: true,
  },
});
