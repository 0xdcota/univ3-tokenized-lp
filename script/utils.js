function logNewLine(type, message) {
  const currentTime = getTime();
  const year = currentTime.getFullYear();
  const month = pad(currentTime.getMonth() + 1, 2); // Month value is zero-based (0 - 11)
  const day = pad(currentTime.getDate(), 2);
  const hours = pad(currentTime.getHours(), 2);
  const minutes = pad(currentTime.getMinutes(), 2);
  const seconds = pad(currentTime.getSeconds(), 2);
  const milliseconds = pad(currentTime.getMilliseconds(), 3);
  console.log(
    `\n${year}-${month}-${day} ${hours}:${minutes}:${seconds}.${milliseconds} ${type} - ${message}`
  );
}

module.exports = {
  logNewLine,
};
