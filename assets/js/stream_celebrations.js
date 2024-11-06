let hooks = {};

hooks.StreamCelebrations = {
  mounted() {
    this.handleEvent("goal-reached", () => {
      this.celebrateGoal();
    });
  },

  celebrateGoal() {
    const template = document.getElementById("goal-celebration");
    const celebration = template.content.cloneNode(true);
    document.body.appendChild(celebration);

    // Add confetti or other animations
    confetti({
      particleCount: 100,
      spread: 70,
      origin: { y: 0.6 }
    });

    setTimeout(() => {
      celebration.remove();
    }, 5000);
  }
};

export default hooks; 