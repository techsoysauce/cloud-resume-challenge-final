var xhr = new XMLHttpRequest();

xhr.open('POST', 'https://lerv96nuki.execute-api.us-east-1.amazonaws.com/add_count');


xhr.onload = function () {
  if (xhr.readyState === xhr.DONE) {
    if (xhr.status === 200) {
      document.getElementById("CounterVisitor").innerHTML = '&nbsp;&nbsp;' + xhr.responseText + ' views&nbsp;&nbsp;';

    }
  }
};

xhr.send(null);

