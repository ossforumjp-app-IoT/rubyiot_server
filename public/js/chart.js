function draw(sensorid, start, span) {
  var options = {
    chart: {
      width:500,
      heigth:300
    },
    title: {
      text: 'Monthly Temperature',
      x: -20 //center
    },
    xAxis: {
      categories: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    },
    yAxis: {
      title: {
        text: 'Temperature (°C)'
      },
      plotLines: [{
        value: 0,
        width: 1,
        color: '#808080'
      }]
    },
    tooltip: {
      valueSuffix: '°C'
    },
    legend: {
      layout: 'vertical',
      align: 'right',
      verticalAlign: 'middle',
      borderWidth: 0
    },
    series: [{
      name: 'Tokyo',
      data: [7.0, 6.9, 9.5, 14.5, 18.2, 21.5, 25.2, 26.5, 23.3, 18.3, 13.9, 9.6]
    }]
  };

  var apiUri = "/api/sensor_data";
  apiUri += "?sensor_id=" + sensorid;
  apiUri += "&start=" + start.replace(" ", "+");
  apiUri += "&span=" + span;

  jQuery.get(apiUri, function(contents) {
    var cats = new Array();
    var dats = new Array();

    for(var key in contents){
      cats.push(key);
      dats.push(contents[key] - 0);
    };

    options["title"] = {text: span.toUpperCase() + " Temperature", x: -20}
    options["xAxis"] = {categories: cats};
    options["series"] = [{name: "sensor " + sensorid, data: dats}]

    // グラフを作成
    $('#container').highcharts(options);
  });
};
