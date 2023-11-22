const SOCKET_PATH = '/tmp/sim.sock';

const net      = require('net'),
      readline = require('readline'),
      Matter   = require('matter-js'),
      fs       = require('fs');
const { v4: uuid } = require('uuid');

var port = 5000,
    unixsocket = SOCKET_PATH;

var Engine = Matter.Engine,
    World  = Matter.World,
    Events = Matter.Events,
    Vector = Matter.Vector,
    Bodies = Matter.Bodies,
    Body   = Matter.Body;

var upcase = function(string) {
  return string.charAt(0).toUpperCase() + string.slice(1);
}


function Sim(engine, world) {
  this.engine     = engine;
  this.world      = world;
  this.bodies     = {};
  this.collisions = [];

  this.tick = function(opts) {
    this.collisions.length = 0;
    Engine.update(this.engine, opts.step_ms);
    return true
  };

  this.addRectangle = function(opts) {
    var width       = opts.width,
        height      = opts.height,
        density     = opts.density,
        friction    = opts.friction,
        restitution = opts.restitution,
        position    = opts.position,
        static      = opts.static,
        frictionAir = opts.frictionAir,
        frictionStatic = opts.frictionStatic;

    var body = Bodies.rectangle(
      position.x, position.y, width, height,
      { isStatic: static, density: density,
        friction: friction, frictionAir: frictionAir,
        frictionStatic: frictionStatic, restitution: restitution }
    );

    body.width = width;
    body.height = height;
    body.shape = 'rectangle';

    World.add(this.world, [body]);
    return this.trackBody(body);
  };

  this.addSquare = function(opts) {
    var width    = opts.width,
        position = opts.position,
        static   = opts.static;

    var body = Bodies.rectangle(
      position.x, position.y, width, width, { isStatic: static }
    )

    body.width = width;
    body.height = width;
    body.shape = 'square';

    World.add(this.world, [body]);
    return this.trackBody(body);
  };

  this.destroy = function(opts) {
    var body = this.findBody(opts.body_uuid);
    if(body) {
      Matter.World.remove(world, [body])
      this.stopTrackingBody(body);
      return true;
    };
    return false;
  };

  this.push = function(opts) {
    // TODO: currently causes tick not to work
    var body      = this.findBody(opts.body_uuid),
        direction = opts.direction,
        force     = Vector.create(direction.x / 100, direction.y / 100),
        position  = Vector.create(body.position.x, body.position.y);
        //position  = Vector.create(0, 0);

    Body.applyForce(body, position, force);
    return true
  };

  this.setVelocity = function(opts) {
    var body      = this.findBody(opts.body_uuid),
        velocity  = opts.velocity;
    Body.setVelocity(body, { x: velocity.x, y: velocity.y });
    return true;
  };

  this.setRotation = function(opts) {
    var body      = this.findBody(opts.body_uuid),
        rotation  = opts.rotation;
    Body.setAngle(body, rotation);
    return true;
  };

  this.setPosition = function(opts) {
    var body     = this.findBody(opts.body_uuid),
        position = Vector.create(opts.position.x, opts.position.y);
    Body.setPosition(body, position);
    return true
  };

  this.detail = function(opts) {
    var body = this.findBody(opts.body_uuid);
    return {
      position: { x: body.position.x, y: body.position.y },
      velocity: { x: body.velocity.x, y: body.velocity.y },
      rotation: body.angle,
      body_uuid: body.uuid,
      width: body.width,
      height: body.height,
      shape: body.shape,
      static: body.isStatic
    };
  };

  this.setGravity = function(opts) {
    if(typeof opts.x !== "undefined") {
      this.world.gravity.x = opts.x
    }
    if(typeof opts.y !== "undefined") {
      this.world.gravity.y = opts.y
    }
    return {
      x: this.world.gravity.x,
      y: this.world.gravity.y
    }
  };

  this.setAntiGravity = function(opts) {
    var body = this.findBody(opts.body_uuid);
    body.antiGravity = true;
    return true;
  };

  this.findBody = function(body_uuid) {
    return this.bodies[body_uuid];
  };

  this.stopTrackingBody = function(body) {
    delete this.bodies[body.uuid];
  };

  this.listBodies = function() {
    var bodies = Object.keys(this.bodies);
    return bodies;
  };

  this.trackBody = function(body) {
    var body_uuid = uuid();
    body.uuid = body_uuid;
    this.bodies[body_uuid] = body;
    return body_uuid;
  };

  this.handleCollision = function(event) {
    //this.collisions.push([ event.pairs.bodyA, event.pairs.bodyB ]);
    var collisions = this.collisions;
    event.pairs.forEach(function(pair) {
      collisions.push([pair.bodyA, pair.bodyB]);
    });
    return true;
  };

  var dis = this;
  Events.on(
    engine,
    'collisionStart',
    function(event) {
      dis.handleCollision(event);
    }
  );
};

function Commander(sim) {
  this.sim = sim;

  this.tick = function(opts) {
    var collisions = this.sim.collisions.map(
      function(pair) {
        return { pair: pair.map(function(body) { return body.uuid }) };
      }
    );
    this.sim.tick(opts);
    return { collisions: collisions };
  };

  this.destroy = function(opts) {
    this.sim.destroy({
      body_uuid: opts.body_uuid
    });
    return { body_uuid: opts.body_uuid };
  };

  this.add_square = function(opts) {
    var body_uuid = this.sim.addSquare({
      width:    opts.size,
      static:   opts.static,
      position: { x: opts.position.x, y: opts.position.y },
    });
    return { body_uuid: body_uuid };
  };

  this.add_rectangle = function(opts) {
    let args = {
      width:          opts.width,
      height:         opts.height,
      static:         opts.static,
      density:        opts.density || 0.05,
      friction:       opts.friction || 0.01,
      restitution:    opts.restitution || 0.01,
      frictionAir:    opts.frictionAir || 0.01,
      frictionStatic: opts.frictionStatic || 0.5,
      position:       { x: opts.position.x, y: opts.position.y },
    }
    var body_uuid = this.sim.addRectangle(args);
    return { body_uuid: body_uuid };
  };

  this.add = function(opts) {
    opts.static = opts.static || false;
    return this[`add_${opts.shape}`](opts);
  };

  this.push = function(opts) {
    this.sim.push({
      body_uuid: opts.body_uuid,
      direction: opts.direction
    })
    return { body_uuid: opts.body_uuid };
  };

  this.set_velocity = function(opts) {
    this.sim.setVelocity({
      body_uuid: opts.body_uuid,
      velocity:   opts.velocity
    });
    return { body_uuid: opts.body_uuid };
  };

  this.set_rotation = function(opts) {
    this.sim.setRotation({
      body_uuid: opts.body_uuid,
      rotation:  opts.rotation
    });
    return { body_uuid: opts.body_uuid };
  };

  this.set_position = function(opts) {
    this.sim.setPosition({
      body_uuid: opts.body_uuid,
      position: opts.position
    });
    return { body_uuid: opts.body_uuid };
  }

  this.set_gravity = function(opts) {
    return this.sim.setGravity({x: opts.x, y: opts.y});
  };

  this.set_anti_gravity = function(opts) {
    this.sim.setAntiGravity({
      body_uuid: opts.body_uuid
    });
    return { body_uuid: opts.body_uuid }
  };

  this.detail = function(opts) {
    return this.sim.detail({ body_uuid: opts.body_uuid });
  };

  this.list_details = function(opts) {
    var obj = this;
    return this.list_bodies().map(function(body_details) {
      return obj.detail(body_details);
    });
  };

  this.list_bodies = function(opts) {
    return this.sim.listBodies().map(function(uuid) {
      return { body_uuid: uuid }
    });
  }
};


var collisions = [];

var engine = Engine.create(),
    world  = engine.world;

//engine.positionIterations = 10;
//engine.velocityIterations = 8;

// Events.on(world, 'afterAdd', function(event) {
// });

var sim       = new Sim(engine, world),
    commander = new Commander(sim);

function handleMessage(message) {
  return commander[message.message](message);
};

function handle(socket) {
  var rl = readline.createInterface({ input: socket });
  rl.on('line', function(line) {
    var inputData = JSON.parse(line);
    var response_data = handleMessage(inputData);
    response_data.request_id = inputData.request_id
    // blocking write?
    socket.write(JSON.stringify(response_data));
    socket.write("\n");
  });
};

if(fs.existsSync(SOCKET_PATH)) {
  fs.unlinkSync(SOCKET_PATH);
};
var server = net.createServer(handle);
server.listen(unixsocket);

server.on('err', function(err) {
  console.log(err);
  server.close(function() {
    console.log("shutting down the server!");
    fs.unlink(SOCKET_PATH);
  });
});

console.log("starting");

//setInterval(function() {
//  Engine.update(engine, 1000 / 60);
//}, 1000 / 60);
