import main 1.0
import QtQuick 2.2
import QtQuick.Particles 2.0
import Box2D 1.1

Body {
    id: body
    property var model
    property string playerImage
    property real lightWidth: 50;

    width: playerDiameterMeters * world.pixelsPerMeter
    height: playerDiameterMeters * world.pixelsPerMeter
    linearDamping: 1
    angularDamping: 1
    sleepingAllowed: true
    bullet: true // Ensures that the player doesn't jump over bodies within a step
    bodyType: Body.Dynamic
    fixtures: Circle {
        anchors.fill: parent
        radius: width / 2
        density: 1
        friction: 0.4
        restitution: 1
        LightedImage {
            id: image
            anchors.fill: parent
            sourceImage: playerImage
            normalsImage: "saucer_normals.png"
            lightSources: lights
            Text {
                x : (parent.width - contentWidth) / 2
                y : (parent.height - contentHeight) / 2
                width: parent.width / 2
                height: parent.height / 2
                color: "#7fffffff"
                fontSizeMode: Text.Fit
                font.pointSize: 72
                font.weight: Font.Bold
                font.family: "Arial"
                text: model ? model.name.slice(0, 2) : ""
            }
        }
        Emitter {
            id: fireEmitter
            system: flamePainter.system
            width: 25
            height: 25
            anchors.centerIn: parent
            enabled: false

            lifeSpan: 160

            velocity: PointDirection { xVariation: width * 2; yVariation: height * 2 }

            size: 24
            sizeVariation: size
        }
    }
    Connections {
        target: model
        onTouchMove: {
            function velocityDifferenceVector(toProj, onto) {
                // Find what part of the push to removed in account for the current velocity
                // of the body (like when you can't get any faster on a bicycle unless you
                // start pedaling faster than what the current speed is rotating the traction
                // wheel).
                // There is surely a better formula than this, but here take the projection
                // of the input movement onto the current velocity vector, and remove that part,
                // clamping what we remove between 0 and the length of the velocity vector.
                var unitOnto = onto.normalized()
                var projLength = toProj.dotProduct(unitOnto)
                var effectiveProjLength = Math.max(0, Math.min(projLength, onto.length()))
                return unitOnto.times(effectiveProjLength)
            }
            // Moving the finger 100px per second will be linearly reduced by a speed of 1m per second.
            var inputPixelPerMeter = 100
            // How much fraction of a second it takes to reach the mps described by the finger.
            // 1/8th of a second will be needed for the ball to reach the finger mps speed
            // (given that we only accelerate using the velocity difference between the controller
            // and the player body).
            var accelFactor = body.getMass() * 8

            var moveTime = time ? time : 16
            var bodyVelMPS = body.linearVelocity
            var moveVecMPS = Qt.vector2d(x, y).times(1000 / moveTime / inputPixelPerMeter)
            var velVecMPS = Qt.vector2d(bodyVelMPS.x, bodyVelMPS.y)
            var inputAdjustmentVec = velocityDifferenceVector(moveVecMPS, velVecMPS)
            var adjustedMove = moveVecMPS.minus(inputAdjustmentVec)

            var appliedForce = adjustedMove.times(accelFactor)
            body.applyForceToCenter(Qt.point(appliedForce.x, appliedForce.y))

            var v = Qt.vector2d(x, y)
            var fireVel = v.normalized().times(-200)
            fireEmitter.velocity.x = fireVel.x
            fireEmitter.velocity.y = fireVel.y
            fireEmitter.burst(v.length())
            if (body.lightWidth < root.width / 3)
                body.lightWidth += v.length() * 5
        }
    }
    Component.onCompleted: {
        var jsArray = [body]
        for (var i in lights.sources)
            jsArray.push(lights.sources[i])
        lights.sources = jsArray
    }
    Component.onDestruction: {
        var jsArray = []
        for (var i in lights.sources) {
            var o = lights.sources[i]
            if (o != body)
                jsArray.push(o)
        }
        lights.sources = jsArray
    }
    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: if (body.lightWidth > 0) body.lightWidth -= 50
    }
}