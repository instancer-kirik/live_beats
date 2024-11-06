let hooks = {};

hooks.TipAnimations = {
  mounted() {
    this.handleEvent("big-tip-animation", ({amount, from}) => {
      const template = document.getElementById("tip-animation");
      const animation = template.content.cloneNode(true);
      document.body.appendChild(animation);
      
      setTimeout(() => {
        animation.remove();
      }, 3000);
    });
  }
};

export default hooks; 