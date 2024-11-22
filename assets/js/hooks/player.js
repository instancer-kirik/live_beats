import Hls from "hls.js";

const Player = {
  mounted() {
    this.player = this.el;
    this.streamKey = this.el.dataset.streamKey;
    
    if (Hls.isSupported()) {
      this.hls = new Hls();
      this.hls.loadSource(`/hls/${this.streamKey}/playlist.m3u8`);
      this.hls.attachMedia(this.player);
      
      this.hls.on(Hls.Events.MANIFEST_PARSED, () => {
        // Video is ready to play
        this.handleEvents();
      });
      
      this.hls.on(Hls.Events.ERROR, (event, data) => {
        if (data.fatal) {
          switch (data.type) {
            case Hls.ErrorTypes.NETWORK_ERROR:
              // Try to recover network error
              console.log("Fatal network error encountered, trying to recover");
              this.hls.startLoad();
              break;
            case Hls.ErrorTypes.MEDIA_ERROR:
              console.log("Fatal media error encountered, trying to recover");
              this.hls.recoverMediaError();
              break;
            default:
              // Cannot recover
              this.hls.destroy();
              break;
          }
        }
      });
    } else if (this.player.canPlayType("application/vnd.apple.mpegurl")) {
      // Native HLS support (Safari)
      this.player.src = `/hls/${this.streamKey}/playlist.m3u8`;
      this.handleEvents();
    }
  },

  handleEvents() {
    this.player.addEventListener("play", () => {
      this.pushEvent("play", {});
    });

    this.player.addEventListener("pause", () => {
      this.pushEvent("pause", {});
    });

    this.player.addEventListener("timeupdate", () => {
      this.pushEvent("timeupdate", { currentTime: this.player.currentTime });
    });

    this.handleEvent("play", () => {
      this.player.play();
    });

    this.handleEvent("pause", () => {
      this.player.pause();
    });
  },

  destroyed() {
    if (this.hls) {
      this.hls.destroy();
    }
  }
};

export default Player;
